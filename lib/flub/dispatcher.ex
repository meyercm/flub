alias Flub.EtsHelper.{Subscribers, Dispatchers}
defmodule Flub.Dispatcher do
  @moduledoc false
  use GenServer
  import ShorterMaps

  ##############################
  # Global API
  ##############################

  @spec publish(any, any) :: any
  def publish(msg, channel) do
    # send it to this channel
    for pid <- find_all(channel) do
      send(pid, {:publish, msg})
    end
    msg
  end

  def subscribe(pid, :local, channel, filter, mapper) do
    subscribe(pid, node(), channel, filter, mapper)
  end
  def subscribe(pid, node, channel, filter, mapper) do
    if node != node() do
      Flub.NodeSync.maintain_connection(node)
    end
    case Dispatchers.find(node, channel) do
      :undefined ->
        {:ok, server_pid} = Flub.DispatcherSup.start_worker(node, channel)
        server_pid
      server_pid ->
        case Process.alive?(server_pid) do
          true -> server_pid
          false ->
            {:ok, new_server_pid} = Flub.DispatcherSup.start_worker(node, channel)
            new_server_pid
        end
    end
    |> GenServer.call({:subscribe, pid, filter, mapper})
    :ok
  end

  @spec unsubscribe(pid) :: :ok
  def unsubscribe(pid) do
    Dispatchers.multi_call({:unsubscribe, pid})
  end

  @spec unsubscribe(pid, any) :: :ok
  def unsubscribe(pid, channel) do
    Dispatchers.find(node(), channel)
    |> GenServer.call({:unsubscribe, pid})
  end
  def unsubscribe(pid, pub_node, channel) do
    Dispatchers.find(pub_node, channel)
    |> GenServer.call({:unsubscribe, pid})
  end

  ##############################
  # Instance API
  ##############################
  @spec start_link(atom, any) :: {:ok, pid} | :ignore | {:error, any}
  def start_link(node, channel) do
    GenServer.start_link(__MODULE__, [node, channel])
  end


  defmodule State do
    @moduledoc false
    defstruct [
      subscribers: %{}, # pid => %{monitor: ref,
                        #          pid: pid,
                        #          funs => [{:filter, :mapper}, ...]}
      node: nil,
      channel: nil,
    ]
  end
  ##############################
  # GenServer Callbacks
  ##############################
  def init([node, channel]) do
    :pg2.create({__MODULE__, node, channel})
    :pg2.join({__MODULE__, node, channel}, self)
    Dispatchers.create(node, channel, self)
    subscribers = Subscribers.find(channel)
                  |> Enum.map(fn({pid, funs}) ->
                                {pid, add_subscriber(channel, pid, funs)}
                              end)
                  |> Enum.into(%{})
    {:ok, ~M{%State node channel subscribers}}
  end

  def handle_call(:subscribers, _from, ~M{subscribers} = state) do
    pids = Map.keys(subscribers)
    {:reply, pids, state}
  end
  def handle_call({:subscribe, pid, filter, mapper}, _from, ~M{channel subscribers} = state) do
    subscriber = case Map.get(subscribers, pid, nil) do
      nil -> add_subscriber(channel, pid, {filter, mapper})
      sub -> update_subscriber(channel, sub, {filter, mapper})
    end
    {:reply, :ok, %{state|subscribers: put_in(subscribers[pid], subscriber)}}
  end
  def handle_call({:unsubscribe, pid}, _from, state) do
    state = remove_subscriber(state, pid)
    {:reply, :ok, state}
  end

  def handle_cast(:stop, ~M{subscribers node channel} = state) do
    case Enum.any?(subscribers) do
      true -> {:noreply, state}
      false ->
        Dispatchers.remove(node, channel)
        {:stop, :normal, state}
    end
  end

  def handle_info({:publish, msg}, ~M{subscribers} = state) do
    for ~M{pid funs} <- Map.values(subscribers) do
      for {filter, mapper} <- funs do
        send_to_subs(pid, msg, filter, mapper)
      end
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _info}, state) do
    state = remove_subscriber(state, pid)
    {:noreply, state}
  end

  ##############################
  # Internal Calls
  ##############################
  require Logger


  def find_all(channel) do
    case :pg2.get_members({__MODULE__, node(), channel}) do
      list when is_list(list) -> list
      _error -> []
    end
  end

  @cancel_pub Flub.cancel_pub

  def send_to_subs(_pid, _msg, false, _), do: :ok
  def send_to_subs(_pid, @cancel_pub, true, _), do: :ok
  def send_to_subs(pid, msg, true, :identity), do: send(pid, msg)
  def send_to_subs(pid, msg, true, mapper) do
    {f, m} = try do
               {true, mapper.(msg)}
             rescue error ->
               Logger.error("FLUB: publishing #{inspect msg}, error in mapper lambda: #{inspect error}")
               {false, :error}
             end
    send_to_subs(pid, m, f, :identity)
  end
  def send_to_subs(pid, msg, f, mapper) do
    match = try do
              f.(msg.data)
            rescue error ->
              Logger.error("FLUB publishing #{inspect msg}, error in filter lambda: #{inspect error}")
              false
            end
    send_to_subs(pid, msg, match, mapper)
  end

  def update_subscriber(channel, ~M{funs pid} = sub, fun) do
    Subscribers.update(channel, pid, [fun|funs])
    %{sub|funs: [fun|funs]}
  end

  def add_subscriber(channel, pid, {filter, mapper}) do
    add_subscriber(channel, pid, [{filter, mapper}])
  end
  def add_subscriber(channel, pid, funs) do
    Subscribers.update(channel, pid, funs)
    monitor = Process.monitor(pid)
    ~M{channel funs pid monitor}
  end

  def remove_subscriber(~M{channel subscribers} = state, pid) do
    case Map.get(subscribers, pid) do
      nil -> :no_op
      ~M{monitor} ->
        Process.demonitor(monitor)
        Subscribers.remove(channel, pid)
    end
    subscribers = Map.delete(subscribers, pid)
    if Enum.empty?(subscribers) do
      GenServer.cast(self, :stop)
    end
    %{state|subscribers: subscribers}
  end

end
