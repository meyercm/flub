alias Flub.EtsHelper.{Subscribers}
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

  def subscribe(pid, node_or_modifier, channel, filter, mapper)
  def subscribe(pid, :local, channel, filter, mapper) do
    find_or_start_dispatcher(node(), channel)
    |> GenServer.call({:subscribe, pid, filter, mapper})
  end
  def subscribe(pid, :global, channel, filter, mapper) do
    find_or_start_dispatcher(:global, channel)
    |> GenServer.call({:subscribe, pid, filter, mapper})
  end
  def subscribe(pid, other_node, channel, filter, mapper) do
    Flub.NodeSync.maintain_connection(node)
    find_or_start_dispatcher(other_node, channel)
    |> GenServer.call({:subscribe, pid, filter, mapper})
  end

  @spec unsubscribe(pid) :: :ok
  def unsubscribe(client) do
    all_dispatchers
    |> Enum.each(fn pid -> GenServer.call(pid, {:unsubscribe, client}) end)
  end

  @spec unsubscribe(pid, any) :: :ok
  def unsubscribe(client, channel) do
    case find_dispatcher(node(), channel) do
      :undefined -> :ok
      pid -> GenServer.call(pid, {:unsubscribe, client})
    end
  end
  def unsubscribe(client, pub_node, channel) do
    case find_dispatcher(pub_node, channel) do
      :undefined -> :ok
      pid -> GenServer.call(pid, {:unsubscribe, client})
    end
  end


  @doc false
  def find_dispatcher(node, channel) do
    case :gproc.lookup_pids({:n, :l, {__MODULE__, node, channel}}) do
      [] -> :undefined
      [pid] -> pid
    end
  end

  @doc false
  def find_or_start_dispatcher(node, channel) do
    case find_dispatcher(node, channel) do
      :undefined ->
        {:ok, pid} = Flub.DispatcherSup.start_worker(node, channel)
        pid
      pid -> pid
    end
  end

  @doc false
  def all_dispatchers do
    :gproc.lookup_pids({:p, :l, __MODULE__})
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
    :gproc.reg({:n, :l, {__MODULE__, node, channel}})
    :gproc.reg({:p, :l, __MODULE__})
    :pg2.create({__MODULE__, node, channel})
    :pg2.join({__MODULE__, node, channel}, self)
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

  def handle_cast(:stop, ~M{subscribers} = state) do
    case Enum.any?(subscribers) do
      true -> {:noreply, state}
      false -> {:stop, :normal, state}
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
    pg2_groups = [
      {__MODULE__, node(), channel},
      {__MODULE__, :global, channel},
    ]
    for group <- pg2_groups do
      case :pg2.get_members(group) do
        list when is_list(list) -> list
        _error -> []
      end
    end
    |> List.flatten
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
