defmodule Flub.NodeSync.Worker do
  @moduledoc false
  use GenServer
  import ShorterMaps
  ##############################
  # API
  ##############################

  def start(node) do
    case :gproc.lookup_pids({:n, :l, {__MODULE__, node}}) do
      [] -> Flub.NodeSync.Supervisor.start_child(node)
      [pid] -> {:ok, pid}
    end
  end

  def start_link(node) do
    GenServer.start_link(__MODULE__, [node])
  end

  def release(node) do
    :gproc.lookup_pid({:n, :l, {__MODULE__, node}})
    |> GenServer.cast(:release_connection)
  end

  defmodule State do
    @moduledoc false
    defstruct [
      node: nil,
      fsm: :pinging,
    ]
  end

  ##############################
  # GenServer Callbacks
  ##############################
  @ping_period 5000

  def init([node]) do
    :gproc.reg({:n, :l, {__MODULE__, node}})
    :gproc.reg({:p, :l, __MODULE__})
    state = ~M{%State node}
            |> check_node
    {:ok, state}
  end

  def handle_cast(:release_connection, state) do
    {:stop, :normal, state}
  end
  def handle_info({:nodedown, node}, %{node: node, fsm: :monitor} = state) do
    {:noreply, check_node(state)}
  end
  def handle_info(:periodic_check, %{fsm: :monitor} = state) do
    {:noreply, state}
  end
  def handle_info(:periodic_check, %{fsm: :pinging} = state) do
    {:noreply, check_node(state)}
  end

  ##############################
  # Internal Calls
  ##############################

  def check_node(~M{node} = state) do
    case Node.ping(node) do
      :pong -> switch_to_monitor(state)
      _ -> switch_to_ping(state)
    end
  end

  def switch_to_monitor(~M{node} = state) do
    Node.monitor(node, true)
    %{state|fsm: :monitor}
  end
  def switch_to_ping(state) do
    Process.send_after(self, :periodic_check, @ping_period)
    %{state|fsm: :pinging}
  end

end
