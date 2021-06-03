defmodule FlubHelpersTest do
  use ExUnit.Case
  require Flub
  use Flub.Helpers

  setup do
    on_exit fn ->
      Flub.unsub
      Process.sleep(10)
    end
  end

  # define a channel
  define_channel("test_channel", foo: "foo", bar: :bar)

  test "default struct members" do
    data = %__MODULE__.TestChannel{}
    assert(data.foo == "foo")
    assert(data.bar == :bar)
  end

  test "pub and sub via macro" do
    channel = test_channel_chnl()
    sub_test_channel()
    data = %__MODULE__.TestChannel{}
    pub_test_channel(data)
    Flub.pub(data, channel)
    assert_receive(%Flub.Message{channel: ^channel, data: ^data})
  end
end
