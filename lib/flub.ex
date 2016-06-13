defmodule Flub do
  alias Flub.Dispatcher
  import ShorterMaps
  ##############################
  # API
  ##############################
  defmodule Message do
    defstruct [
      data: nil,
      channel: nil,
      node: nil,
    ]
  end

  @all_channels __MODULE__.AllChannels
  def all_channels, do: @all_channels

  def open_channels(), do: Flub.EtsHelper.Dispatchers.all

  def pub(data, channel \\ @all_channels) do
    ~M{%Message data channel node}
    |> Dispatcher.publish(channel)
  end

  def sub(channel \\ @all_channels) do
    f = fn(_) -> true end
    Dispatcher.subscribe(self, f, channel)
  end


  defmacro sub(pattern, channel, node \\ :local)
  defmacro sub(true, channel, node) do
    quote do
      Flub.do_sub(unquote(node), unquote(channel), true)
    end
  end
  defmacro sub(pattern, channel, node) do
    quote do
      f = fn (msg) ->
        case(msg) do
         unquote(pattern) -> true
         _                -> false
        end
      end
      Flub.do_sub(unquote(node), unquote(channel), f)
    end
  end

  def do_sub(:local, channel, fun_or_true) do
    Dispatcher.subscribe(self, fun_or_true, channel)
  end
  def do_sub(other_node, channel, fun_or_true) do
    :rpc.call(other_node, Dispatcher, :subscribe, [self, fun_or_true, channel])
  end

  def subscribers(channel) do
    Dispatcher.subscribers(channel)
  end

  def unsub do
    Dispatcher.unsubscribe(self)
  end
  def unsub(channels) do
    Dispatcher.unsubscribe(self, channels)
  end


end
