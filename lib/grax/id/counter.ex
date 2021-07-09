defmodule Grax.Id.Counter do
  def path, do: Application.get_env(:grax, :counter_dir, ".")

  def path(filename) do
    path = path()
    File.mkdir_p!(path)
    Path.join(path, filename)
  end

  def registry, do: Grax.Id.Counter.Registry

  def process_name(adapter, name), do: {adapter, name}

  def process(adapter, name) do
    registry()
    |> Registry.lookup(process_name(adapter, name))
    |> case do
      [] -> Grax.Id.Counter.Supervisor.start_counter!(adapter, name)
      [{pid, nil}] -> pid
    end
  end
end
