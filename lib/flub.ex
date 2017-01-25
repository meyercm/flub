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

  def cancel_pub, do: Flub.CancelPub

  def pub(data, channel) do
    ~M{%Message data channel node}
    |> Dispatcher.publish(channel)
    data
  end

  @default_filter true
  @default_mapper :identity
  @default_node :local
  @default_sub_opts [filter: @default_filter, mapper: @default_mapper, node: @default_node]

  def sub(channel), do: sub(channel, @default_sub_opts)
  def sub(channel, opts) when is_list(opts) do
    filter = Keyword.get(opts, :filter, @default_filter)
    mapper = Keyword.get(opts, :mapper, @default_mapper)
    node = Keyword.get(opts, :node, @default_node)
    Dispatcher.subscribe(self, node, channel, filter, mapper)
  end

  defmacro p(pattern) do
    quote do
      fn (msg) ->
        case(msg) do
         unquote(pattern) -> true
         _                -> false
        end
      end
    end
  end

  def unsub do
    Dispatcher.unsubscribe(self)
  end
  def unsub(channel) do
    Dispatcher.unsubscribe(self, channel)
  end


end
