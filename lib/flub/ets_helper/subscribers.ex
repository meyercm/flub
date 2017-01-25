defmodule Flub.EtsHelper.Subscribers do
  @moduledoc false
  import Ex2ms

  @table __MODULE__

  def setup, do: EtsOwner.create_table(@table, :bag)

  def create(channel, pid, funs) do
    :ets.insert(@table, {channel, pid, funs})
  end

  def remove(channel, pid) do
    ms = fun do {^channel, ^pid, _} = ob -> ob end
    for matching <- :ets.select(@table, ms) do
      :ets.delete_object(@table, matching)
    end
  end

  def find(channel) do
    ms = fun do {^channel, pid, funs} -> {pid, funs} end
    :ets.select(@table, ms)
  end

  def update(channel, pid, funs) do
    remove(channel, pid)
    create(channel, pid, funs)
  end

end
