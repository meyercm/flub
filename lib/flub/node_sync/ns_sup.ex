defmodule Flub.NodeSync.Supervisor do
  @moduledoc false
  use Supervisor

  #############
  # API
  #############

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def start_child(the_node) do
    Supervisor.start_child(__MODULE__, [the_node])
  end

  ##############################
  # GenServer Callbacks
  ##############################

  def init([]) do
    children = [
      worker(Flub.NodeSync.Worker, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  ##############################
  # Internal
  ##############################

end
