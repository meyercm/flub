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
        {:ok, pid} = Flub.DispatcherSup.start_worker(channel)
        pid
      pid ->
        case Process.alive?(pid) do
          true -> pid
          false ->
            {:ok, pid} = Flub.DispatcherSup.start_worker(channel)
            pid
        end
    end
    |> GenServer.cast({:subscribe, pid, fun})
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
    Dispatchers.multi_cast({:unsubscribe, pid})
  end

  @spec unsubscribe(pid, any) :: :ok
  def unsubscribe(pid, channel) do
    Dispatchers.find(channel)
    |> GenServer.cast({:unsubscribe, pid})
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
    state = Subscribers.find(channel)
            |> Enum.reduce(~M{%State channel},
                           fn({pid, funs}, acc) ->
                             add_subscriber(acc, pid, funs)
                           end)
    {:ok, state}
  end

  def handle_call(:subscribers, _from, ~M{subscribers} = state) do
    pids = Map.keys(subscribers)
    {:reply, pids, state}
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
  def handle_cast({:subscribe, pid, fun}, state) do
    state = add_subscriber(state, pid, fun)
    {:noreply, state}
  end
  def handle_cast({:unsubscribe, pid}, state) do
    state = remove_subscriber(state, pid)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _info}, state) do
    state = remove_subscriber(state, pid)
    {:noreply, state}
  end

  ##############################
  # Internal Calls
  ##############################

  def send_to_subs(pid, funs, msg) do
    match = Enum.any?(funs, fn f ->
                              try do f.(msg.data) rescue _ -> false end
                            end)
    if match do
      send(pid, msg)
    end
  end

  def add_subscriber(~M{channel subscribers} = state, pid, funs) when is_list(funs) do
    subscribers = case Map.get(subscribers, pid) do
      %{funs: old_funs} = sub ->
        funs = funs ++ old_funs
        Subscribers.update(channel, pid, funs)
        Map.put(subscribers, pid, %{sub|funs: funs})
      nil ->
        Subscribers.create(channel, pid, funs)
        monitor = Process.monitor(pid)
        Map.put(subscribers, pid, ~M{funs pid monitor})
    end
    %{state|subscribers: subscribers}
  end
  def add_subscriber(state, pid, fun) when is_function(fun) do
    add_subscriber(state, pid, [fun])
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
