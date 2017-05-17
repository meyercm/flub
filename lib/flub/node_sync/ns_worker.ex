defmodule Flub.NodeSync.Worker do
  @moduledoc false
  use GenServer
  import ShorterMaps
  ##############################
  # API
  ##############################

  def start(the_node) do
    case :gproc.lookup_pids({:n, :l, {__MODULE__, the_node}}) do
      [] -> Flub.NodeSync.Supervisor.start_child(the_node)
      [pid] -> {:ok, pid}
    end
  end

  def start_link(the_node) do
    GenServer.start_link(__MODULE__, [the_node])
  end

  def release(the_node) do
    :gproc.lookup_pid({:n, :l, {__MODULE__, the_node}})
    |> GenServer.cast(:release_connection)
  end

  defmodule State do
    @moduledoc false
    defstruct [
      the_node: nil,
      fsm: :pinging,
    ]
  end

  ##############################
  # GenServer Callbacks
  ##############################
  @ping_period 5000

  def init([the_node]) do
    :gproc.reg({:n, :l, {__MODULE__, the_node}})
    :gproc.reg({:p, :l, __MODULE__})
    state = ~M{%State the_node}
            |> check_the_node
    {:ok, state}
  end

  def handle_cast(:release_connection, state) do
    {:stop, :normal, state}
  end
  def handle_info({:nodedown, the_node}, %{the_node: the_node, fsm: :monitor} = state) do
    {:noreply, check_the_node(state)}
  end
  def handle_info(:periodic_check, %{fsm: :monitor} = state) do
    {:noreply, state}
  end
  def handle_info(:periodic_check, %{fsm: :pinging} = state) do
    {:noreply, check_the_node(state)}
  end

  ##############################
  # Internal Calls
  ##############################

  def check_the_node(~M{the_node} = state) do
    case Node.ping(the_node) do
      :pong -> switch_to_monitor(state)
      _ -> switch_to_ping(state)
    end
  end

  def switch_to_monitor(~M{the_node} = state) do
    Node.monitor(the_node, true)
    %{state|fsm: :monitor}
  end
  def switch_to_ping(state) do
    Process.send_after(self(), :periodic_check, @ping_period)
    %{state|fsm: :pinging}
  end

end
