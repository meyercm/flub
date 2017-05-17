defmodule Flub do
  @moduledoc """
  Flub is a pub-sub application intended to simplify larger applications.

  Even in Elixir and OTP applications, close coupling modules can lead you into
  dark places.  When one process publishes and another subscribes, neither needs
  to be specifically aware of the other.  Additionally, extending the
  functionality of existing applications is much easier when new modules can just
  hook into existing published event streams.

  ## Examples:

  ### Basic subscription
  ```elixir

      # subscriber pid:
      iex> Flub.sub(:trigger_channel)

      # publishing pid:
      iex> Flub.pub(:new_trigger, :trigger_channel)

      # subscriber pid:
      iex> flush
      :ok
      %Flub.Message{channel: :trigger_channel, data: :new_trigger,
        node: :nonode@nohost}
  ```

  ### Pattern Matching (data, not channels)

  The `p/1` macro creates filter lambdas by expanding a `case` statement.
  Requesting a filter prevents non-matching data from being sent to the
  subscriber. Any lambda which accepts the published data, and returns
  `true|false` can be used as a filter.
  ```
      # subscriber pid.  Note channel is a 2-tuple in this example.
      iex> Flub.sub({Worker, 1}, filter: p(%Worker.CompletionIndication{}))

      # publisher pid:
      iex> Flub.pub(%OtherIndication{}, {Worker, 1})) # <= subscriber won't receive
      iex> Flub.pub(%Worker.CompletionIndication{task_id: 5}, {Worker, 1})

      # subscriber pid:

      iex> flush
      :ok
      %Flub.Message{channel: {Worker, 1},
                    data: %WorkerCompletionIndication{task_id: 5},
                    node: :nonode@nohost}
  ```

  ### Publish Mapping

  By specifying a `:mapper` lambda, a subscriber can request published messages
  be transformed before being sent, or prevent their arrival entirely by returning
  the special value `Flub.cancel_pub`

  ```elixir

      # subscriber pid:
      iex> Flub.sub(:test_chan, mapper: fn %Flub.Message{data: :fake} -> Flub.cancel_pub
                                           %Flub.Message{data: :real} -> {42, :real}
                                        end)
      # publisher pid:
      iex> Flub.pub(:fake, :test_chan)
      iex> Flub.pub(:real, :test_chan)

      # subscriber_pid:
      iex> flush
      :ok
      {42, real}  #Note: There is no %Flub.Message{} struct wrapping the data.
  ```

  ### Cross Node Subscription

  Subscribers can request to listen for events originating on a specfic remote
  node.

  ```elixir
      # subscriber pid:
      iex> node()
      :this_node@my-host
      iex> Flub.sub("a channel", node: :other_node@their-host)

      # publisher (on :other_node@their-host)
      Flub.pub({:new_data, 12}, "a channel")

      # subscriber:
      iex> flush
      :ok
      %Flub.Message{channel: "a channel", data: {:new_data, 12}, node: :other_node@their-host}

  ```

  ### Global Subscription

  Alternately, a subscriber can elect to receive all messages published to a
  channel, regardless of the originating node:

  ```elixir

  iex> Flub.sub("important channel", node: :global)
  :ok
  ```

  """


  alias Flub.Dispatcher
  import ShorterMaps
  ##############################
  # API
  ##############################
  defmodule Message do
    @moduledoc """
    The metadata struct wrapping published messages.

    - `data`: the term published in `Flub.pub/2`
    - `channel`: the channel published to in `Flub.pub/2`
    - `node`: which node was `Flub.pub/2` invoked on
    """
    defstruct [
      data: nil,
      channel: nil,
      node: nil,
    ]
  end

  @doc """
  Value that cancels a publication  during mapping (see `:mapper` option to
  `sub/2`, below)
  """
  def cancel_pub, do: Flub.CancelPub

  @doc """
  Publishes a piece of data to all subscribers.

  This method has extremely low overhead for the publisher in all cases, and
  essentially zero overhead for the entire application when there are no
  subscribers for the publish.

  Both data and channel may be any term.
  Returns the data for use in pipelining, vis-a-vis `IO.inspect`

  ## Examples

      iex> Flub.pub(:mydata, :mychannel)
      :mydata

  """
  def pub(data, channel) do
    ~M{%Message data, channel, node()}
    |> Dispatcher.publish(channel)
    data
  end

  @default_filter true
  @default_mapper :identity
  @default_node :local
  @default_sub_opts [filter: @default_filter, mapper: @default_mapper, node: @default_node]

  @doc """
  Subscribes to a channel.

  Subscribing to a channel implies that any messages published on the channel are
  passed to the subscriber as the `:data` key in a `%Flub.Message{}` struct,
  subject to the options described below.

  Options:

  - `filter`: most commonly used with the `p/1` macro, the filter key must be a lambda
      that returns `true|false`, or a literal `true` (the default). Published
      messages are passed to the filter lambda, and sent to the subscriber iff
      the lambda evalutes to `true` with the message as an argument.
  - `mapper`: a lambda which accepts the `%Flub.Message{}` struct for a message which
      has already passed the filter requirement described above.  The return
      value from this method will be sent to the subscriber, unless a special
      value is returned (the method `Flub.cancel_pub()` provides it), in which
      case nothing is published to that subscriber.  The default value of
      `:identity` makes no change. Errors occuring during the mapper lambda are
      rescued and logged; the publish does not occur.  Note that this lambda is
      not executed by the subscriber.
  - `node`: which node to subscribe to the channel on.  Note that subscribers are
      always responsible for the cross-node setup in the Flub architecture.
      Subscribing to a channel on a remote node does not imply subscribing to
      the same channel on the local node, which would require a second call to
      `Flub.sub`.  Setting `:node` to its default of `:local` creates the
      subscription on the local node. Alternately, setting `:node` to `:global`
      subscribes to the channel across all nodes.

  ## Examples:

      # in the subscribing pid.
      iex> Flub.sub(:my_channel)
      :ok

      # in the publisher:
      iex> Flub.pub(:my_data, :my_channel)

      # back in the subscribing pid.
      iex> flush
      %Flub.Message{data: :my_data, channel: :my_channel, node: :nonode@nohost}

  """
  def sub(channel, opts \\ @default_sub_opts) when is_list(opts) do
    filter = Keyword.get(opts, :filter, @default_filter)
    mapper = Keyword.get(opts, :mapper, @default_mapper)
    the_node = Keyword.get(opts, :node, @default_node)
    Dispatcher.subscribe(self(), the_node, channel, filter, mapper)
  end

  @doc """
  Helper macro to generate filter lambdas.  This provides a pattern-matching
  function for the subscription filter option to `sub/2`

  An example expansion:

      p(%{id: _}) |  fn %{id: _} -> true
                  |            _ -> false
                  |  end

  ## Examples

      # Will match any map with an `:id` key set to 1:
      iex> Flub.sub("a channel", filter: p(%{id: 1}))

      # Will match any map with an `:id` key:
      iex> Flub.sub(:another_channel, filter: p(%{id: _id}))

      # Will match any `%Models.Person` struct:
      iex> Flub.sub({DataWorker, 1}, filter: p(%Models.Person{}))

  """
  defmacro p(pattern) do
    quote do
      fn unquote(pattern) -> true
                        _ -> false
      end
    end
  end

  @doc """
  Unsubscribe from all channels.
  """
  def unsub do
    Dispatcher.unsubscribe(self())
  end

  @doc """
  Unsubscribe from a single channel.
  """
  def unsub(channel) do
    Dispatcher.unsubscribe(self(), channel)
  end


end
