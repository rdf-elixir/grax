defmodule RDF.Mapping.Schema do
  alias RDF.PropertyMap

  @doc """
  Defines a mapping schema.
  """
  defmacro schema(do: block) do
    schema(__CALLER__, block)
  end

  defp schema(caller, block) do
    prelude =
      quote do
        if line = Module.get_attribute(__MODULE__, :rdf_mapping_schema_defined) do
          raise "schema already defined for #{inspect(__MODULE__)} on line #{line}"
        end

        @rdf_mapping_schema_defined unquote(caller.line)

        Module.register_attribute(__MODULE__, :rdf_property_mapping, accumulate: true)
        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)

        try do
          import unquote(__MODULE__)
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        unless Module.defines?(__MODULE__, {:__struct__, 0}, :def) do
          defstruct [:__iri__ | @struct_fields]
        end

        @property_map PropertyMap.new(@rdf_property_mapping)
        def __property_map__, do: @property_map
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro property(name, iri, opts \\ []) do
    quote do
      RDF.Mapping.Schema.__property__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  @doc false
  def __property__(mod, name, iri, opts) do
    define_property(mod, name, iri, opts)
  end

  defp define_property(mod, name, iri, opts) do
    Module.put_attribute(mod, :struct_fields, {name, Keyword.get(opts, :default)})

    Module.put_attribute(mod, :rdf_property_mapping, {name, iri})
  end
end
