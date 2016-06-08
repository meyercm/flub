# Flub

Flub does Pub. Flub does Sub. Flub does PubSub, bub.

## Usage:

```elixir

iex> Flub.sub() # <= subscribe for all published messages
:ok
...> Flub.pub(:msg)

```

## Installation

The package can be installed as:

  1. Add Flub to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:flub, github: "meyercm/flub"}]
    end
    ```

  2. Ensure channels is started before your application:

    ```elixir
    def application do
      [applications: [:flub]]
    end
    ```
