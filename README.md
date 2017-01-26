# Flub

Flub does Pub. Flub does Sub. Flub does PubSub, bub.

## Major Changes

#### v1.0

 - the `sub` macro has been removed in favor of simpler composition using the
new `p/1` macro. See below for details and new examples.
 - Remote node subscriptions have been overhauled and dramatically robustified.

## Motivation

Even in Elixir and OTP applications, close coupling modules can lead you into
dark places.  When one process publishes and another subscribes, neither needs
to be specifically aware of the other.  Additionally, extending the
functionality of existing applications is much easier when new modules can just
hook into existing published event streams.

## Strategy

Flub's event flow is subscriber driven:  subscribing to a channel is the only
action that 'creates' a channel, by starting a channel "dispatcher".  When
publishing an event, Flub first checks to see if a dispatcher is running for the
channel: no dispatcher implies no subscribers, and the publisher does nothing.

When a dispatcher is running, the publisher sends the raw data to the dispatcher,
who wraps it in a `Flub.Message` struct, providing channel and node of origin
metadata, then passes the message to each subscribed pid.
      ___________              ____________                 _______________
     | Publisher |    data    | Dispatcher |    message    | Subscriber(s) |
     |___________|  =======>  |____________|  ==========>  |_______________|


## Usage

### Simple: consume the whole channel

```elixir
iex> Flub.sub(MyTopic) # <= subscribe to a particular channel
:ok
...> Flub.pub({Interesting, :data}, MyTopic) # <= publish to that channel
:ok
...> flush
%Flub.Message{channel: MyTopic, data: {Interesting, :data}, node: :'nonode@nohost'}
:ok
```

### Filtering subscriptions via Pattern Matching

```elixir
iex> require Flub # needed for the `p/1` macro
...> Flub.sub(MyNewTopic, filter: p(%{key: _value}))  
...> Flub.pub(%{key: :value, other: "other"}, MyNewTopic)
...> flush
%Flub.Message{channel: MyNewTopic, data: %{key: :value, other: "other"}, node: :'nonode@nohost'}
:ok
...> Flub.pub(%{key2: :value2}, MyNewTopic)
...> flush
# No messages received
:ok
```

### Realistic use cases

A typical use of `Flub` is for a `GenServer` to advertise when new data becomes
available or important state changes occur - letting API clients avoid polling
loops.

#### Lightly modified example: Serial port line buffer

This is a simplification of a real SerialPort worker, that publishes new
full lines received on a serial port.  For the `~M` sigil, see [ShorterMaps](https://github.com/meyercm/shorter_maps)

In the code below, we assume that a serial library is sending a message to
this `GenServer` each time a character is received. Each time a full line is
completed, the `GenServer` publishes both the raw string and the decoded
representation (a struct, in our case) to the appropriate Flub channels.  

```elixir
  def handle_info({:new_serial_data, data}, ~M{device buffer} = state) do
    {new_buffer, new_lines} = update_line_buffer(buffer, data)
    for line <- new_lines do
      decoded = SerialCodec.decode(line)
      Flub.pub(line, {__MODULE__.Raw, device})
      Flub.pub(decoded, {__MODULE__.Decoded, device})
    end
    {:noreply, %{new_state|buffer: new_buffer}}
  end
```

Several other GenServers in the application are subscribed to these channels,
consuming the decoded messages and taking appropriate actions.

## API Summary

#### Publish data to Subscribers `:pub/2`

- `pub(data, channel)` publish data to the specified channel

#### Subscribe for data `:sub/1, sub/2`

- `sub(channel)` subscribe to all events on a specific channel
- `sub(channel, opts = [filter: filter, mapper: mapper, node: node])`
  - `filter`: a lambda that filters published messages sent to this subscriber.
  - `mapper`: a lambda that transforms published messages sent to this subscriber.
  - `node`: subscribe to events on a remote node.

### Filter Helper Macro `:p/1`

- `p(pattern)` expands to `fn pattern -> true; _ -> false end`
- typical usage, e.g.: `Flub.sub(:mychan, filter: p(%MyStruct{}))`

#### Unsubscribe `unsub/0, unsub/1`

- `unsub()` cancel all subscriptions on all channels
- `unsub(channel)` cancel all subscriptions on a specific channel

## Installation

The package can be installed as:

  1. Add Flub to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:flub, "~> 1.0"},
      ]
    end
    ```

  2. Ensure Flub is started before your application:

    ```elixir
    def application do
      [applications: [:flub]]
    end
    ```

-----

If you do something cool with `Flub`, drop me a line
