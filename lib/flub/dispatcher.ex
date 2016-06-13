alias Flub.EtsHelper.{Subscribers, Dispatchers}
defmodule Flub.Dispatcher do
  use GenServer
  import ShorterMaps

  ##############################
  # Global API
  ##############################
  @all_channels Flub.all_channels

  @spec publish(any, any) :: :ok
  def publish(msg, @all_channels) do
    Dispatchers.multi_cast({:publish, msg})
    :ok
  end
  def publish(msg, channel) do
    # send it to this channel
    case Dispatchers.find(channel) do
      :undefined -> :no_dispatcher
      pid -> GenServer.cast(pid, {:publish, msg})
    end
    # also send it to the @all_channels channel
    case Dispatchers.find(@all_channels) do
      :undefined -> :ok
      pid -> GenServer.cast(pid, {:publish, msg})
    end
    :ok
  end

  def all_subscribe(pid) do
    f = fn(_) -> true end
    subscribe(pid, f, @all_channels)
  end

  @spec subscribe(pid, (... -> boolean), any) :: :ok
  def subscribe(pid, fun, channel) do
    case Dispatchers.find(channel) do
      :undefined ->
        {:ok, server_pid} = Flub.DispatcherSup.start_worker(channel)
        server_pid
      server_pid ->
        case Process.alive?(server_pid) do
          true -> server_pid
          false ->
            {:ok, new_server_pid} = Flub.DispatcherSup.start_worker(channel)
            new_server_pid
        end
    end
    |> GenServer.call({:subscribe, pid, fun})
    :ok
  end

  @spec subscribers(any) :: [pid, ...]
  def subscribers(channel) do
    case Dispatchers.find(channel) do
      :undefined -> []
      pid -> GenServer.call(pid, :subscribers)
    end
  end

  @spec unsubscribe(pid) :: :ok
  def unsubscribe(pid) do
    Dispatchers.multi_call({:unsubscribe, pid})
  end

  @spec unsubscribe(pid, any) :: :ok
  def unsubscribe(pid, channel) do
    Dispatchers.find(channel)
    |> GenServer.call({:unsubscribe, pid})
  end

  ##############################
  # Instance API
  ##############################
  @spec start_link(any) :: {:ok, pid} | :ignore | {:error, any}
  def start_link(channel) do
    GenServer.start_link(__MODULE__, [channel])
  end


  defmodule State do
    defstruct [
      subscribers: %{}, # pid => ~M{funs monitor pid}
      channel: nil,
    ]
  end
  ##############################
  # GenServer Callbacks
  ##############################
  def init([channel]) do
    Dispatchers.create(channel, self)
    subscribers = Subscribers.find(channel)
                  |> Enum.map(fn({pid, funs}) ->
                                {pid, add_subscriber(channel, pid, funs)}
                              end)
                  |> Enum.into(%{})
    {:ok, ~M{%State channel subscribers}}
  end

  def handle_call(:subscribers, _from, ~M{subscribers} = state) do
    pids = Map.keys(subscribers)
    {:reply, pids, state}
  end
  def handle_call({:subscribe, pid, fun}, _from, ~M{channel subscribers} = state) do
    subscriber = case Map.get(subscribers, pid, nil) do
      nil -> add_subscriber(channel, pid, fun)
      sub -> update_subscriber(channel, sub, fun)
    end
    {:reply, :ok, %{state|subscribers: put_in(subscribers[pid], subscriber)}}
  end
  def handle_call({:unsubscribe, pid}, _from, state) do
    state = remove_subscriber(state, pid)
    {:reply, :ok, state}
  end

  def handle_cast(:stop, ~M{subscribers channel} = state) do
    case Enum.any?(subscribers) do
      true -> {:noreply, state}
      false ->
        Dispatchers.remove(channel)
        {:stop, :normal, state}
    end
  end
  def handle_cast({:publish, msg}, ~M{subscribers} = state) do
    for ~M{pid funs} <- Map.values(subscribers) do
      send_to_subs(pid, funs, msg)
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
  def send_to_subs(pid, true, msg) do
    #Logger.debug("sending to #{inspect pid}")
    send(pid, msg)
  end
  def send_to_subs(pid, funs, msg) do
    match = Enum.any?(funs, fn f ->
                              try do f.(msg.data) rescue _ -> false end
                            end)
    if match do
      send_to_subs(pid, true, msg)
    end
  end

  def update_subscriber(channel, %{funs: true} = sub, _fun), do: sub
  def update_subscriber(channel, ~M{pid} = sub, true) do
    Subscribers.update(channel, pid, true)
    %{sub|funs: true}
  end
  def update_subscriber(channel, ~M{funs pid} = sub, fun) do
    Subscribers.update(channel, pid, [fun|funs])
    %{sub|funs: [fun|funs]}
  end

  def add_subscriber(channel, pid, fun) when is_function(fun) do
    add_subscriber(channel, pid, [fun])
  end
  def add_subscriber(channel, pid, funs) do
    Subscribers.create(channel, pid, funs)
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
