defmodule Grax.Schema do
  @moduledoc """
  A special type of struct for graph structures whose fields are mapped to RDF properties and
  the types of values can be specified.

  For now there is no API documentation.
  Read about schemas in the guide [here](https://rdf-elixir.dev/grax/schemas.html).
  """

  alias Grax.Schema.{Struct, Inheritance, DataProperty, LinkProperty, CustomField}
  alias RDF.IRI

  @type t() :: struct

  defmacro __using__(opts) do
    preload_default = opts |> Keyword.get(:depth) |> Grax.normalize_preload_spec()

    id_spec_from_otp_app =
      if id_spec_from_otp_app = Keyword.get(opts, :id_spec_from_otp_app) do
        Application.get_env(id_spec_from_otp_app, :grax_id_spec)
      end

    id_spec = Keyword.get(opts, :id_spec, id_spec_from_otp_app)

    quote do
      import unquote(__MODULE__), only: [schema: 1, schema: 2]

      @before_compile unquote(__MODULE__)

      @grax_preload_default unquote(preload_default)
      def __preload_default__(), do: @grax_preload_default

      if unquote(id_spec) do
        def __id_spec__(), do: unquote(id_spec)
      else
        def __id_spec__() do
          __MODULE__
          |> Application.get_application()
          |> Application.get_env(:grax_id_spec)
        end
      end

      def __id_schema__(id_spec \\ nil)
      def __id_schema__(nil), do: if(id_spec = __id_spec__(), do: __id_schema__(id_spec))
      def __id_schema__(id_spec), do: id_spec.id_schema(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __id__(attributes), do: Grax.id(__MODULE__, attributes)

      def build(id), do: Grax.build(__MODULE__, id)
      def build(id, initial), do: Grax.build(__MODULE__, id, initial)
      def build!(id), do: Grax.build!(__MODULE__, id)
      def build!(id, initial), do: Grax.build!(__MODULE__, id, initial)

      @spec load(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              {:ok, __MODULE__.t()} | {:error, any}
      def load(graph, id, opts \\ []), do: Grax.load(__MODULE__, id, graph, opts)

      @spec load!(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              __MODULE__.t()
      def load!(graph, id, opts \\ []), do: Grax.load!(__MODULE__, id, graph, opts)

      Module.delete_attribute(__MODULE__, :rdf_property_acc)
      Module.delete_attribute(__MODULE__, :custom_field_acc)
    end
  end

  defmacro schema(class \\ nil, do_block)

  defmacro schema([inherit: parent_schema], do: block) do
    schema(__CALLER__, nil, List.wrap(parent_schema), block)
  end

  defmacro schema({:<, _, [class, nil]}, do: block) do
    schema(__CALLER__, class, nil, block)
  end

  defmacro schema({:<, _, [class, parent_schema]}, do: block) do
    schema(__CALLER__, class, List.wrap(parent_schema), block)
  end

  defmacro schema(class, do: block) do
    schema(__CALLER__, class, nil, block)
  end

  defp schema(caller, class, parent_schema, block) do
    prelude =
      quote do
        if line = Module.get_attribute(__MODULE__, :grax_schema_defined) do
          raise "schema already defined for #{inspect(__MODULE__)} on line #{line}"
        end

        @grax_schema_defined unquote(caller.line)

        @grax_parent_schema unquote(parent_schema)
        def __super__(), do: @grax_parent_schema

        @grax_schema_class if unquote(class), do: IRI.to_string(unquote(class))
        def __class__(), do: @grax_schema_class

        Module.register_attribute(__MODULE__, :rdf_property_acc, accumulate: true)
        Module.register_attribute(__MODULE__, :custom_field_acc, accumulate: true)

        try do
          import unquote(__MODULE__)
          import Grax.Schema.Type.Constructors
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        @type t() :: %__MODULE__{}

        @__properties__ Inheritance.inherit_properties(
                          __MODULE__,
                          @grax_parent_schema,
                          Map.new(@rdf_property_acc)
                        )

        @__custom_fields__ Inheritance.inherit_custom_fields(
                             __MODULE__,
                             @grax_parent_schema,
                             Map.new(@custom_field_acc)
                           )

        defstruct Struct.fields(@__properties__, @__custom_fields__)

        def __properties__, do: @__properties__

        def __properties__(:data),
          do: @__properties__ |> Enum.filter(&match?({_, %DataProperty{}}, &1))

        def __properties__(:link),
          do: @__properties__ |> Enum.filter(&match?({_, %LinkProperty{}}, &1))

        def __property__(property), do: @__properties__[property]

        def __custom_fields__, do: @__custom_fields__
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro field(name, opts \\ []) do
    quote do
      Grax.Schema.__custom_field__(__MODULE__, unquote(name), unquote(opts))
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
  def __custom_field__(mod, name, opts) do
    custom_field_schema = CustomField.new(mod, name, opts)
    Module.put_attribute(mod, :custom_field_acc, {name, custom_field_schema})
  end

  @doc false
  def __property__(mod, name, iri, opts) when not is_nil(iri) do
    property_schema = DataProperty.new(mod, name, iri, opts)
    Module.put_attribute(mod, :rdf_property_acc, {name, property_schema})
  end

  @doc false
  def __link__(mod, name, iri, opts) do
    property_schema = LinkProperty.new(mod, name, iri, opts)

    Module.put_attribute(mod, :rdf_property_acc, {name, property_schema})
  end

  @doc false
  def has_field?(schema, field_name) do
    Map.has_key?(schema.__properties__(), field_name) or
      Map.has_key?(schema.__custom_fields__(), field_name)
  end

  defp property_mapping_destination({:-, _line, [iri_expr]}), do: {:inverse, iri_expr}
  defp property_mapping_destination(iri_expr), do: iri_expr
end
