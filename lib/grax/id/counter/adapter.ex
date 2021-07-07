defmodule Grax.Id.Counter.Adapter do
  @type value :: non_neg_integer

  @callback value(pid) :: {:ok, value} | {:error, any}

  @callback inc(pid) :: {:ok, value} | {:error, any}

  @callback reset(pid, value) :: :ok | {:error, any}
end
