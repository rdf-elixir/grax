defmodule Grax.Id.Schema do
  alias Grax.Id.Namespace
  alias Grax.Id.Schema.Extension

  @type template :: struct
  @type t :: %__MODULE__{
          namespace: Namespace.t(),
          template: template,
          schema: module | [module],
          selector: {module, atom} | nil,
          counter: {module, atom} | nil,
          var_mapping: {module, atom} | nil,
          extensions: list | nil
        }

  @enforce_keys [:namespace, :template, :schema]
  defstruct [:namespace, :template, :schema, :selector, :counter, :var_mapping, :extensions]

  def new(namespace, template, opts) do
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
        counter: counter_tuple(namespace, opts),
        var_mapping: Keyword.get(opts, :var_mapping),
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

  defp counter_tuple(namespace, opts) do
    opts
    |> Keyword.get(:counter)
    |> counter_tuple(namespace, opts)
  end

  defp counter_tuple(nil, _, _), do: nil

  defp counter_tuple(name, namespace, opts) do
    {
      Keyword.get(opts, :counter_adapter) ||
        Namespace.option(namespace, :counter_adapter) ||
        Grax.Id.Counter.default_adapter(),
      name
    }
  end

  def generate_id(id_schema, variables, opts \\ [])

  def generate_id(%__MODULE__{} = id_schema, variables, opts) when is_list(variables) do
    generate_id(id_schema, Map.new(variables), opts)
  end

  def generate_id(%__MODULE__{} = id_schema, %_{} = mapping, opts) do
    generate_id(id_schema, Map.from_struct(mapping), opts)
  end

  def generate_id(%__MODULE__{} = id_schema, variables, opts) do
    variables =
      variables
      |> add_schema_var(id_schema)
      |> add_counter_var(id_schema)

    with {:ok, variables} <- var_mapping(id_schema, variables),
         {:ok, variables} <- Extension.call(id_schema, variables, opts),
         {:ok, variables} <- preprocess_variables(id_schema, variables),
         {:ok, segment} <- YuriTemplate.expand(id_schema.template, variables) do
      {:ok, expand(id_schema, segment, opts)}
    end
  end

  def parameters(%{template: template}), do: YuriTemplate.parameters(template)

  defp preprocess_variables(id_schema, variables) do
    parameters = parameters(id_schema)

    parameters
    |> Enum.filter(fn parameter -> is_nil(Map.get(variables, parameter)) end)
    |> case do
      [] ->
        {:ok,
         variables
         |> Map.take(parameters)
         |> Map.new(fn {variable, value} -> {variable, to_string(value)} end)}

      missing ->
        {:error, "no value for id schema template parameter: #{Enum.join(missing, ", ")}"}
    end
  end

  defp add_schema_var(_, %{schema: nil} = id_schema) do
    raise "no schema found in id schema #{inspect(id_schema)}"
  end

  defp add_schema_var(variables, %{schema: schema}) do
    Map.put(variables, :__schema__, schema)
  end

  defp add_counter_var(variables, %{counter: nil}), do: variables

  defp add_counter_var(variables, %{counter: {adapter, name}}) do
    case adapter.inc(name) do
      {:ok, value} -> Map.put(variables, :counter, value)
      {:error, error} -> raise error
    end
  end

  defp var_mapping(%__MODULE__{var_mapping: {mod, fun}}, variables),
    do: apply(mod, fun, [variables])

  defp var_mapping(_, variables), do: {:ok, variables}

  def expand(id_schema, id_segment, opts \\ [])

  def expand(%__MODULE__{} = id_schema, id_segment, opts) do
    expand(id_schema.namespace, id_segment, opts)
  end

  def expand(namespace, id_segment, _opts) do
    RDF.iri(to_string(namespace) <> id_segment)
  end

  def option(opts, key, id_schema) do
    Keyword.get(opts, key) ||
      Namespace.option(id_schema.namespace, key)
  end

  def option!(opts, key, id_schema) do
    option(opts, key, id_schema) ||
      raise ArgumentError, "required #{inspect(key)} keyword argument missing"
  end
end
