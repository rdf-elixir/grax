defmodule Grax.Id.Counter.Adapter do
  alias Grax.Id.Counter

  @type value :: non_neg_integer

  @callback value(pid) :: {:ok, value} | {:error, any}

  @callback inc(pid) :: {:ok, value} | {:error, any}

  @callback reset(pid, value) :: :ok | {:error, any}

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour unquote(__MODULE__)

      @default_value 0

      def via_process_name(name) do
        {:via, Registry, {Counter.registry(), Counter.process_name(__MODULE__, name)}}
      end

      def process(name) do
        Grax.Id.Counter.process(__MODULE__, name)
      end
    end
  end
end
