defmodule Grax.Link.NotLoaded do
  @moduledoc !"""
             Struct returned by links when they are not loaded.

             The fields are:

               * `__field__` - the link field in `owner`
               * `__owner__` - the schema that owns the link
             """

  @type t :: %__MODULE__{
          __field__: atom(),
          __owner__: any()
        }

  defstruct [:__field__, :__owner__]

  defimpl Inspect do
    def inspect(not_loaded, _opts) do
      msg = "link #{inspect(not_loaded.__field__)} is not loaded"
      ~s(#Grax.Link.NotLoaded<#{msg}>)
    end
  end
end
