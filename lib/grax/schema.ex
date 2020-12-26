defmodule Grax.Schema do
  @moduledoc false

  alias Grax.Schema.{DataProperty, LinkProperty}
  alias Grax.Link
  alias RDF.IRI

  @doc """
  Defines a Grax schema.
  """
  defmacro schema(class \\ nil, do: block) do
    schema(__CALLER__, class, block)
  end

  defp schema(caller, class, block) do
    prelude =
      quote do
        if line = Module.get_attribute(__MODULE__, :grax_schema_defined) do
          raise "schema already defined for #{inspect(__MODULE__)} on line #{line}"
        end

        @grax_schema_defined unquote(caller.line)

        @grax_schema_class if unquote(class), do: IRI.to_string(unquote(class))
        def __class__(), do: @grax_schema_class

        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
        Module.register_attribute(__MODULE__, :rdf_property_acc, accumulate: true)

        try do
          import unquote(__MODULE__)
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        defstruct [:__id__ | @struct_fields]

        @__properties__ Map.new(@rdf_property_acc)
        def __properties__, do: @__properties__

        def __properties__(:data),
          do: @__properties__ |> Enum.filter(&match?({_, %DataProperty{}}, &1))

        def __properties__(:link),
          do: @__properties__ |> Enum.filter(&match?({_, %LinkProperty{}}, &1))

        def __property__(property), do: @__properties__[property]
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro property(name, iri, opts \\ []) do
    quote do
      Grax.Schema.__property__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  defmacro link(name, iri, opts) do
    iri = property_mapping_destination(iri)

    unless Keyword.has_key?(opts, :type),
      do: raise(ArgumentError, "type missing for link #{name}")

    opts =
      opts
      |> Keyword.update!(:type, &expand_alias(&1, __CALLER__))
      |> Keyword.put(:preload, Link.Preloader.normalize_spec(Keyword.get(opts, :preload), true))

    quote do
      Grax.Schema.__link__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  @doc false
  def __property__(mod, name, iri, opts)
  # virtual property
  def __property__(mod, name, nil, opts) do
    Module.put_attribute(mod, :struct_fields, {name, opts[:default]})
  end

  def __property__(mod, name, iri, opts) do
    property_schema = DataProperty.new(mod, name, iri, opts)
    Module.put_attribute(mod, :struct_fields, {name, property_schema.default})
    Module.put_attribute(mod, :rdf_property_acc, {name, property_schema})
  end

  @doc false
  def __link__(mod, name, iri, opts) do
    property_schema = LinkProperty.new(mod, name, iri, opts)

    Module.put_attribute(mod, :struct_fields, {name, LinkProperty.default(property_schema)})
    Module.put_attribute(mod, :rdf_property_acc, {name, property_schema})
  end

  defp property_mapping_destination({:-, _line, [iri_expr]}), do: {:inverse, iri_expr}
  defp property_mapping_destination(iri_expr), do: iri_expr

  defp expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})

  defp expand_alias(ast, _env),
    do: ast
end
