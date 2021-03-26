defmodule Grax.Id.Schema do
  alias Grax.Id
  alias RDF.IRI

  @type template :: struct
  @type t :: %__MODULE__{
          namespace: Namespace.t(),
          template: template,
          schema: struct
        }

  @enforce_keys [:namespace, :template, :schema]
  defstruct [:namespace, :template, :schema]

  def new(%Id.Namespace{} = namespace, template, opts) do
    with {:ok, template} <- init_template(template) do
      %__MODULE__{
        namespace: namespace,
        template: template,
        schema: Keyword.fetch!(opts, :schema)
      }
    else
      {:error, error} -> raise error
    end
  end

  defp init_template(template) do
    YuriTemplate.parse(template)
  end

  def generate_id(%__MODULE__{} = id_schema, mapping) do
    with {:ok, suffix} <- YuriTemplate.expand(id_schema.template, Map.from_struct(mapping)) do
      {:ok,
       id_schema.namespace
       |> Id.Namespace.iri()
       |> IRI.append(suffix)}
    end
  end
end
