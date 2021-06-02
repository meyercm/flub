defmodule Flub.DispatcherSup do
  @moduledoc false

  use DynamicSupervisor

  #############
  # API
  #############

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, [], [name: __MODULE__])

  def start_worker(node, channel), do: DynamicSupervisor.start_child(__MODULE__, %{id: Flub.Dispatcher, start: {Flub.Dispatcher, :start_link, [node, channel]}, restart: :transient})

  ##############################
  # GenServer Callbacks
  ##############################

  @impl DynamicSupervisor
  def init([]), do: DynamicSupervisor.init(strategy: :one_for_one)

  ##############################
  # Internal
  ##############################

end
