defmodule Grax.Id.Schema do
  alias Grax.Id
  alias Grax.Id.Schema.Extension
  alias RDF.IRI

  @type template :: struct
  @type t :: %__MODULE__{
          namespace: Namespace.t(),
          template: template,
          schema: struct,
          selector: {module, atom} | nil,
          var_proc: {module, atom} | nil,
          extensions: list | nil
        }

  @enforce_keys [:namespace, :template, :schema]
  defstruct [:namespace, :template, :schema, :selector, :var_proc, :extensions]

  def new(%Id.Namespace{} = namespace, template, opts) do
    selector = Keyword.get(opts, :selector)
    schema = Keyword.get(opts, :schema)

    unless schema || selector do
      raise ArgumentError, "no :schema or :selector provided on Grax.Id.Schema"
    end

    with {:ok, template} <- init_template(template) do
      %__MODULE__{
        namespace: namespace,
        template: template,
        schema: schema,
        var_proc: Keyword.get(opts, :var_proc),
        selector: selector
      }
      |> Extension.init(Keyword.get(opts, :extensions), opts)
    else
      {:error, error} -> raise error
    end
  end

  defp init_template(template) do
    YuriTemplate.parse(template)
  end

  def generate_id(id_schema, variables, opts \\ [])

  def generate_id(%__MODULE__{} = id_schema, variables, opts) when is_list(variables) do
    generate_id(id_schema, Map.new(variables), opts)
  end

  def generate_id(%__MODULE__{} = id_schema, %_{} = mapping, opts) do
    generate_id(id_schema, Map.from_struct(mapping), opts)
  end

  def generate_id(%__MODULE__{} = id_schema, variables, opts) do
    variables = add_schema_var(id_schema, variables)

    with {:ok, variables} <- var_proc(id_schema, variables),
         {:ok, variables} <- Extension.call(id_schema, variables, opts),
         {:ok, segment} <- YuriTemplate.expand(id_schema.template, variables) do
      {:ok, expand(id_schema, segment, opts)}
    end
  end

  defp add_schema_var(%{schema: nil} = id_schema, _) do
    raise "no schema found in id schema #{inspect(id_schema)}"
  end

  defp add_schema_var(%{schema: schema}, variables) do
    Map.put(variables, :__schema__, schema)
  end

  defp var_proc(%__MODULE__{var_proc: {mod, fun}}, variables), do: apply(mod, fun, [variables])
  defp var_proc(_, variables), do: {:ok, variables}

  def expand(%__MODULE__{} = id_schema, id_segment, _opts \\ []) do
    id_schema.namespace
    |> Id.Namespace.iri()
    |> IRI.append(id_segment)
  end
end
