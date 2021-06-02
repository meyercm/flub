defmodule Flub.NodeSync.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  #############
  # API
  #############

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, [], [name: __MODULE__])

  def start_child(the_node), do: DynamicSupervisor.start_child(__MODULE__, %{id: Flub.NodeSync.Worker, start: {Flub.NodeSync.Worker, :start_link, [the_node]}, restart: :transient})

  ##############################
  # GenServer Callbacks
  ##############################

  def init([]), do: DynamicSupervisor.init(strategy: :one_for_one)

  ##############################
  # Internal
  ##############################

end
