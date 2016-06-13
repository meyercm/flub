defmodule Flub.EtsHelper.Dispatchers do
  @table __MODULE__

  def setup, do: EtsOwner.create_table(@table, :set)

  def create(channel, pid) do
    :ets.insert(@table, {channel, pid})
  end

  def remove(channel) do
    :ets.delete(@table, channel)
  end

  def find(channel) do
    case :ets.lookup(@table, channel) do
      [] -> :undefined
      [{^channel, pid}] -> pid
    end
  end

  def multi_cast(msg) do
    for {_channel, pid} <- :ets.tab2list(@table), do: GenServer.cast(pid, msg)
  end

  def multi_call(msg) do
    for {_channel, pid} <- :ets.tab2list(@table), do: GenServer.call(pid, msg)
  end

  def all() do
    @table
    |> :ets.tab2list
    |> Enum.map(fn {channel, _pid} -> channel end)
  end
end
