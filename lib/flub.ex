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
    ]
  end

  def open_channels(), do: Flub.EtsHelper.Dispatchers.all

  def pub(data, channel) do
    ~M{%Message data channel}
    |> Dispatcher.publish(channel)
  end

  def all_sub() do
    Dispatcher.all_subscribe(self)
  end

  def sub(channel) do
    f = fn(_) -> true end
    Dispatcher.subscribe(self, f, channel)
  end

  defmacro sub(pattern, channel) do
    quote do
      f = fn (msg) ->
        case(msg) do
         unquote(pattern) -> true
         _                -> false
        end
      end
      Dispatcher.subscribe(self, f, unquote(channel))
    end
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
