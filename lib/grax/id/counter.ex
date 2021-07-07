defmodule Grax.Id.Counter do
  def default_counter_dir, do: Application.get_env(:grax, :counter_dir, ".")
end
