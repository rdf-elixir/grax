defmodule Grax.Schema do
  @moduledoc """
  A special type of struct for graph structures whose fields are mapped to RDF properties and
  the types of values can be specified.

  For now there is no API documentation.
  Read about schemas in the guide [here](https://rdf-elixir.dev/grax/schemas.html).
  """

  alias Grax.Schema.{Property, DataProperty, LinkProperty, Field}
  alias RDF.IRI

  defmacro __using__(opts) do
    preload_default = opts |> Keyword.get(:depth) |> Grax.normalize_preload_spec()

    quote do
      import unquote(__MODULE__), only: [schema: 1, schema: 2]

      @before_compile unquote(__MODULE__)

      @grax_preload_default unquote(preload_default)
      def __preload_default__(), do: @grax_preload_default
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def build(id), do: Grax.build(__MODULE__, id)
      def build(id, initial), do: Grax.build(__MODULE__, id, initial)
      def build!(id), do: Grax.build!(__MODULE__, id)
      def build!(id, initial), do: Grax.build!(__MODULE__, id, initial)

      @spec load(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              {:ok, struct} | {:error, any}
      def load(graph, id, opts \\ []), do: Grax.load(__MODULE__, id, graph, opts)

      @spec load!(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              struct
      def load!(graph, id, opts \\ []), do: Grax.load!(__MODULE__, id, graph, opts)

      @doc false
      def __has_property__?(property), do: Keyword.has_key?(@struct_fields, property)

      Module.delete_attribute(__MODULE__, :rdf_property_acc)
      Module.delete_attribute(__MODULE__, :field_acc)
    end
  end

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
        Module.register_attribute(__MODULE__, :field_acc, accumulate: true)

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

        @__fields__ Map.new(@field_acc)
        def __fields__, do: @__fields__
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro field(name, opts \\ []) do
    quote do
      Grax.Schema.__field__(__MODULE__, unquote(name), unquote(opts))
    end
  end

  defmacro property([{name, iri} | opts]) do
    quote do
      Grax.Schema.__property__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
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
      Keyword.put(opts, :preload, opts |> Keyword.get(:depth) |> Grax.normalize_preload_spec())

    quote do
      Grax.Schema.__link__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  defmacro link([{name, iri} | opts]) do
    quote do
      link(unquote(name), unquote(iri), unquote(opts))
    end
  end

  @doc false
  def __field__(mod, name, opts) do
    field_schema = Field.new(name, opts)
    Module.put_attribute(mod, :struct_fields, {name, opts[:default]})
    Module.put_attribute(mod, :field_acc, {name, field_schema})
  end

  @doc false
  def __property__(mod, name, iri, opts) when not is_nil(iri) do
    property_schema = DataProperty.new(mod, name, iri, opts)
    Module.put_attribute(mod, :struct_fields, {name, property_schema.default})
    Module.put_attribute(mod, :rdf_property_acc, {name, property_schema})
  end

  @doc false
  def __link__(mod, name, iri, opts) do
    property_schema = LinkProperty.new(mod, name, iri, opts)

    Module.put_attribute(mod, :struct_fields, {name, Property.default(property_schema.type)})
    Module.put_attribute(mod, :rdf_property_acc, {name, property_schema})
  end

  defp property_mapping_destination({:-, _line, [iri_expr]}), do: {:inverse, iri_expr}
  defp property_mapping_destination(iri_expr), do: iri_expr
end
