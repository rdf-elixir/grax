defmodule Grax.ValidationError do
  @moduledoc """
  Raised when the validation of a Grax fails.
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

defmodule Grax.Entity.TypeError do
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

defmodule Grax.Entity.RequiredPropertyMissing do
  @moduledoc """
  Raised when a required property is not present.
  """
  defexception [:message, :property]

  def exception(opts) do
    property = Keyword.fetch!(opts, :property)
    msg = opts[:message] || "no value for required property #{inspect(property)} present"
    %__MODULE__{message: msg, property: property}
  end
end

defmodule Grax.Entity.InvalidProperty do
  @moduledoc """
  Raised when accessing a property that is not defined on a entity.
  """
  defexception [:message, :property]

  def exception(opts) do
    property = Keyword.fetch!(opts, :property)
    msg = opts[:message] || "undefined property #{inspect(property)}"
    %__MODULE__{message: msg, property: property}
  end
end

defmodule Grax.InvalidIdError do
  @moduledoc """
  Raised when a Grax has an invalid subject id.
  """
  defexception [:message, :id]

  def exception(opts) do
    id = Keyword.fetch!(opts, :id)
    msg = opts[:message] || "invalid subject id: #{inspect(id)}"
    %__MODULE__{message: msg, id: id}
  end
end

defmodule Grax.InvalidValueError do
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
