defmodule Flub.EtsHelper.Dispatchers do
  @moduledoc false
  @table __MODULE__

  def setup, do: EtsOwner.create_table(@table, :set)

  def create(node, channel, pid) do
    :ets.insert(@table, {{node, channel}, pid})
  end

  def remove(node, channel) do
    :ets.delete(@table, {node,channel})
  end

  def find(node, channel) do
    case :ets.lookup(@table, {node, channel}) do
      [] -> :undefined
      [{{^node, ^channel}, pid}] -> pid
    end
  end

  def multi_cast(msg) do
    for {{_node, _channel}, pid} <- :ets.tab2list(@table), do: GenServer.cast(pid, msg)
  end

  def multi_call(msg) do
    for {{_node, _channel}, pid} <- :ets.tab2list(@table), do: GenServer.call(pid, msg)
  end

  def all() do
    @table
    |> :ets.tab2list
    |> Enum.map(fn {channel, _pid} -> channel end)
  end
end
