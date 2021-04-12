defmodule Grax.Utils do
  @moduledoc false

  def rename_keyword(opts, old_name, new_name) do
    if Keyword.has_key?(opts, old_name) do
      opts
      |> Keyword.put(new_name, Keyword.get(opts, old_name))
      |> Keyword.delete_first(old_name)
    else
      opts
    end
  end
end
