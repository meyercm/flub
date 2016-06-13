# Flub

Flub does Pub. Flub does Sub. Flub does PubSub, bub.

## Motivation

Even in Elixir and OTP applications, close coupling modules can lead you into
dark places.  When one process publishes and another subscribes, neither needs
to be specifically aware of the other.  Additionally, extending the
functionality of existing applications is much easier when new modules can just
hook into existing published event streams.

## Features

- `Flub` state is held in `:ets` tables to survive component failures
- `Flub` supports fan-in, fan-out event flows
- Because each channel/topic is hosted by it's own dispatcher, `Flub` scales
nicely with some small forethought
- publishing without subscribers has extremely low overhead; processing is only
conducted when subscribers are listening to a channel.
- Subscriptions support a pattern-matching syntax. See below for details.
- Subscriptions can be made against a remote node running Flub.

## Usage

### Simple, single event stream
```elixir
iex> Flub.sub # <= subscribe for all published messages
:ok
...> Flub.pub(:test) # <= publish to all channels
:ok
...> flush
%Flub.Message{channel: Flub.AllChannels, data: :test, node: :'nonode@nohost'}
:ok
...> Flub.unsub # <= no longer receive messages
[:ok]
```

### Multiple event streams
```elixir
iex> Flub.sub(MyTopic) # <= subscribe to a particular channel
:ok
...> Flub.pub({Interesting, :data}, MyTopic) # <= publish to that channel
:ok
...> flush
%Flub.Message{channel: MyTopic, data: {Interesting, :data}, node: :'nonode@nohost'}
:ok
...> Flub.unsub(MyTopic)
:ok
...> Flub.pub({Interesting, :data}, MyTopic)
:ok
...> flush  
:ok
...> # no messages received
```

### Pattern Matching subscriptions

```elixir
iex> Flub.sub(%{key: value}, MyNewTopic)  # <= sub/0 and /1 are functions
** (CompileError) iex:13: you must require Flub before invoking the macro Flub.sub/2
...> require Flub
nil
...> Flub.sub(%{key: value}, MyNewTopic)
:ok
...> Flub.pub(%{key: :value, other: "other"}, MyNewTopic)
:ok
...> flush
%Flub.Message{channel: MyNewTopic, data: %{key: :value, other: "other"}, node: :'nonode@nohost'}
:ok
...> Flub.pub(%{key2: :value2}, MyNewTopic)
:ok
...> flush
:ok
```

## API

#### Publish data to Subscribers `:pub/1, :pub/2`

- `pub(data)` publish data only to subscribers listening to all events on all channels
- `pub(data, channel)` publish data to the specified channel, and the "all events" channel

#### Subscribe for data `:sub/0, :sub/1, :sub/2, :sub/3`

- `sub()` subscribe to all events on all channels
- `sub(channel)` subscribe to all events on a specific channel
- `sub(pattern, channel)` *(macro)* subscribe to all events that match the given pattern on a specific channel
- `sub(:true, channel, node)` *(macro)* subscribe to all events on a specific channel, originating from a remote node.
- `sub(pattern, channel, node)` *(macro)* subscribe to all events that match the given pattern on a specific channel, originating from a remote node.


#### Unsubscribe `unsub/0, unsub/1`

- `unsub()` cancel all subscriptions on all channels
- `unsub(channels)` cancel all subscriptions on a specific channel

#### Miscellaneous

- `subscribers(channel)` retrieve all pids subscribed to a channel
- `open_channels()` Returns all channels which have an active subscriber
- `all_channels()` Returns the name of the special "all events" channel

## Installation

The package can be installed as:

  1. Add Flub to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:flub, github: "meyercm/flub"}]
    end
    ```

  2. Ensure Flub is started before your application:

    ```elixir
    def application do
      [applications: [:flub]]
    end
    ```
