defmodule Flub.Helpers do
@moduledoc """
  Helper macros for Flub
  """
  defmacro __using__(_opts) do
    quote do
      import Flub, only: [p: 1]
      import Flub.Helpers
    end
  end

  @doc """
  Define a `Flub` channel and associated helper functions. Used like so:

    defmodule PubSub do
      use Flub.Helpers

      define_channel("alert_notice", level: :info, description: "default description")
    end

  the `define_channel` macro will introduce the following code for you:
    ```
    defmodule AlertNotice do
      defstruct [
        level: :info,
        description: "default description",
      ]
    end

    def alert_notice_chnl(), do: :alert_notice
    def pub_alert_notice(val), do: Flub.pub(val, alert_notice_chnl())
    def sub_alert_notice(), do: Flub.sub(alert_notice_chnl())
    def sub_alert_notice(opts), do: Flub.sub(alert_notice_chnl(), opts)
    ```

    Due to the way the structures are injected into your module, you will
    need to reference them with `%__MODULE__.AlertNotice{}`.

    In general, GenServers can use function head matching inn handle_info in
    "the usual way" to process messages:
    ```
    @alert_notice_chnl alert_notice_chnl()
    def handle_info(%Flub.Message{channel: @alert_notice_chnl, data: %__MODULE__.AlertNotice{level: level, description: description}}, state) do
      # use level and description here...
      {:noreply, state}
    end
    ```

  """
  defmacro define_channel(channel_string, channel_def_kwl) do

    # channel string: FooChannel
    camel_channel_string = Macro.camelize(channel_string) # "FooChannel"
    snake_channel_string = Macro.underscore(channel_string) # foo_channel
    channel_atom = String.to_atom(snake_channel_string) # :foo_channel
    struct_mod = String.to_atom("#{__CALLER__.module}.#{camel_channel_string}") # Elixir.PubSub.FooChannel
    get_chnl = String.to_atom("#{snake_channel_string}_chnl") # foo_channel_chnl
    pub_chnl = String.to_atom("pub_#{snake_channel_string}") # pub_foo_channel
    sub_chnl = String.to_atom("sub_#{snake_channel_string}") # sub_foo_channel

    struct = quote do
      defmodule unquote(struct_mod) do
        defstruct unquote(channel_def_kwl)
      end
    end

    funcs = quote do

      def unquote(get_chnl)() do
        unquote(channel_atom)
      end

      def unquote(pub_chnl)(arg) do
        case arg do
          # already a struct, pub it
          %unquote(struct_mod){} -> Flub.pub(arg, unquote(get_chnl)())

          # probably a kwl, convert to struct first then pub
          _ -> Kernel.struct!(unquote(struct_mod), arg) |> Flub.pub(unquote(get_chnl)())
        end
      end

      def unquote(sub_chnl)(opts) do
        Flub.sub(unquote(get_chnl)(), opts)
      end

      def unquote(sub_chnl)() do
        Flub.sub(unquote(get_chnl)())
      end

    end

    [struct, funcs]
  end
end
