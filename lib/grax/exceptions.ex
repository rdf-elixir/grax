defmodule Grax.ValidationError do
  @moduledoc """
  Raised when the validation of a Grax fails.
  """
  defexception [:errors, :context]

  @type t :: %__MODULE__{errors: list, context: any}

  def exception(opts \\ []) do
    errors = Keyword.get(opts, :errors, []) |> List.wrap()
    context = Keyword.get(opts, :context)
    %__MODULE__{errors: errors, context: context}
  end

  def message(validation_error) do
    "validation failed" <>
      if(validation_error.context, do: " in #{inspect(validation_error.context)}", else: "") <>
      if Enum.empty?(validation_error.errors) do
        ""
      else
        """
        :

        - #{Enum.map_join(validation_error.errors, "\n- ", fn {property, error} -> "#{property}: #{Exception.message(error)}" end)}
        """
      end
  end

  def add_error(%__MODULE__{} = validation_error, property, error) do
    %__MODULE__{validation_error | errors: [{property, error} | validation_error.errors]}
  end
end

defmodule Grax.Schema.TypeError do
  @moduledoc """
  Raised when a property value doesn't match the specified type during decoding from RDF.
  """
  defexception [:message, :type, :value]

  def exception(opts) do
    type =
      case Keyword.fetch!(opts, :type) do
        {:resource, type} -> type
        type -> type
      end

    value = Keyword.fetch!(opts, :value)
    msg = opts[:message] || "value #{inspect(value)} does not match type #{inspect(type)}"
    %__MODULE__{message: msg, type: type, value: value}
  end
end

defmodule Grax.Schema.CardinalityError do
  @moduledoc """
  Raised when a the number of property values doesn't match the specified cardinality during decoding from RDF.
  """
  defexception [:message, :cardinality, :value]

  def exception(opts) do
    cardinality = Keyword.fetch!(opts, :cardinality)
    value = Keyword.fetch!(opts, :value)
    msg = opts[:message] || "#{inspect(value)} does not match cardinality #{inspect(cardinality)}"
    %__MODULE__{message: msg, cardinality: cardinality, value: value}
  end
end

defmodule Grax.Schema.InvalidPropertyError do
  @moduledoc """
  Raised when accessing a property that is not defined on a schema.
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

defmodule Grax.InvalidResourceTypeError do
  @moduledoc """
  Raised when a linked resource doesn't match any of the specified classes.
  """
  defexception [:message, :type, :resource_types]

  def exception(opts) do
    type = Keyword.fetch!(opts, :type)
    resource_types = Keyword.fetch!(opts, :resource_types) |> List.wrap()

    msg =
      opts[:message] ||
        "invalid type of linked resource: " <>
          case type do
            :no_match -> "none of the types #{inspect(resource_types)} matches"
            :multiple_matches -> "multiple matches for types #{inspect(resource_types)}"
          end

    %__MODULE__{message: msg, type: type, resource_types: resource_types}
  end
end

defmodule Grax.Schema.DetectionError do
  @moduledoc """
  Raised when no schema could be detected with `Grax.load/3`.
  """
  defexception [:candidates, :context]

  def message(%{candidates: nil, context: context}) do
    "No schema could be detected for #{context}"
  end

  def message(%{candidates: multiple, context: context}) when is_list(multiple) do
    "Multiple possible schemas detected for #{context}"
  end
end
