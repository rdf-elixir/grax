defmodule Grax.Schema.Type do
  @moduledoc !"""
             These are type constructor functions available in a Grax schema block.
             """

  def list(), do: {:list_set, nil}
  def list_of(type), do: {:list_set, type}
end
