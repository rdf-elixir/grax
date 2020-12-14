defmodule RDF.Mapping.ValidationError do
  @moduledoc """
  Raised when the validation of a RDF.Mapping fails.
  """
  defexception [:errors]

  def exception(opts \\ []) do
    %__MODULE__{errors: Keyword.get(opts, :errors, [])}
  end

  def message(validation_error) do
    "validation failed" <>
      if Enum.empty?(validation_error.errors) do
        ""
      else
        """
        :

        - #{
          Enum.map_join(validation_error.errors, "\n- ", fn {property, error} ->
            "#{property}: #{Exception.message(error)}"
          end)
        }
        """
      end
  end

  def add_error(%__MODULE__{} = validation_error, property, error) do
    %__MODULE__{validation_error | errors: [{property, error} | validation_error.errors]}
  end
end

defmodule RDF.Mapping.Schema.TypeError do
  @moduledoc """
  Raised when a property value doesn't match the specified type during decoding from RDF.
  """
  defexception [:message, :type, :value]

  def exception(opts) do
    type = Keyword.fetch!(opts, :type)
    value = Keyword.fetch!(opts, :value)
    msg = opts[:message] || "value #{inspect(value)} does not match type #{inspect(type)}"
    %__MODULE__{message: msg, type: type, value: value}
  end
end

defmodule RDF.Mapping.InvalidSubjectIRIError do
  @moduledoc """
  Raised when a RDF.Mapping has an invalid subject IRI.
  """
  defexception [:message, :iri]

  def exception(opts) do
    iri = Keyword.fetch!(opts, :iri)
    msg = opts[:message] || "invalid subject IRI: #{inspect(iri)}"
    %__MODULE__{message: msg, iri: iri}
  end
end

defmodule RDF.Mapping.InvalidValueError do
  @moduledoc """
  Raised when an invalid literal is encountered during decoding from RDF.
  """
  defexception [:message, :value]

  def exception(opts) do
    value = Keyword.fetch!(opts, :value)
    msg = opts[:message] || "invalid value: #{inspect(value)}"
    %__MODULE__{message: msg, value: value}
  end
end
