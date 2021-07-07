defmodule Grax.Id.Counter.TextFile do
  use GenServer

  @behaviour Grax.Id.Counter.Adapter

  @default_value 0

  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, {name, opts}, name: name)
  end

  @impl true
  def init({name, opts}) do
    {:ok, file_path(name, opts)}
  end

  @impl true
  def value(counter) do
    GenServer.call(counter, :value)
  end

  @impl true
  def inc(counter) do
    GenServer.call(counter, :inc)
  end

  @impl true
  def reset(counter, value \\ @default_value) do
    GenServer.call(counter, {:reset, value})
  end

  @impl true
  def handle_call(:value, _from, path) do
    {:reply, read(path), path}
  end

  @impl true
  def handle_call(:inc, _from, path) do
    {:reply, atomic_inc(path), path}
  end

  @impl true
  def handle_call({:reset, value}, _from, path) do
    {:reply, write(path, value), path}
  end

  def file_path(name, opts \\ []) do
    path = Keyword.get(opts, :path, Grax.Id.Counter.default_counter_dir())
    File.mkdir_p!(path)
    Path.join(path, Atom.to_string(name))
  end

  defp read(path) do
    if File.exists?(path) do
      do_read(path)
    else
      with :ok <- create(path) do
        {:ok, @default_value}
      end
    end
  end

  defp do_read(path) do
    with {:ok, content} <- File.read(path) do
      to_integer(content, path)
    end
  end

  defp to_integer(string, path) do
    case Integer.parse(string) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "Invalid counter value in #{path}"}
    end
  end

  defp write(path, new_value) do
    File.write(path, to_string(new_value))
  end

  defp create(path) do
    write(path, @default_value)
  end

  defp atomic_inc(path) do
    File.open(path, [:read, :write], fn file ->
      file
      |> IO.read(:all)
      |> to_integer(path)
      |> case do
        {:ok, value} ->
          inc_value = value + 1
          :file.position(file, 0)
          IO.write(file, to_string(inc_value))
          {:ok, inc_value}

        error ->
          error
      end
    end)
    |> case do
      {:ok, {:ok, _} = ok} -> ok
      {:ok, {:error, _} = error} -> error
      error -> error
    end
  end
end
