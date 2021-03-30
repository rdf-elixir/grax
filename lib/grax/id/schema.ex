defmodule Grax.Id.Schema do
  alias Grax.Id
  alias Grax.Id.Schema.Extension
  alias RDF.IRI

  @type template :: struct
  @type t :: %__MODULE__{
          namespace: Namespace.t(),
          template: template,
          schema: struct,
          extensions: list | nil
        }

  @enforce_keys [:namespace, :template, :schema]
  defstruct [:namespace, :template, :schema, :extensions]

  def new(%Id.Namespace{} = namespace, template, opts) do
    with {:ok, template} <- init_template(template) do
      %__MODULE__{
        namespace: namespace,
        template: template,
        schema: Keyword.fetch!(opts, :schema)
      }
      |> Extension.init(Keyword.get(opts, :extensions), opts)
    else
      {:error, error} -> raise error
    end
  end

  defp init_template(template) do
    YuriTemplate.parse(template)
  end

  def generate_id(%__MODULE__{} = id_schema, mapping, opts \\ []) do
    variables = Map.from_struct(mapping)

    with {:ok, variables} <- Extension.call(id_schema, variables, opts),
         {:ok, segment} <- YuriTemplate.expand(id_schema.template, variables) do
      {:ok, expand(id_schema, segment, opts)}
    end
  end

  def expand(%__MODULE__{} = id_schema, id_segment, _opts \\ []) do
    id_schema.namespace
    |> Id.Namespace.iri()
    |> IRI.append(id_segment)
  end
end
