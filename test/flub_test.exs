defmodule FlubTest do
  use ExUnit.Case
  require Flub

  setup do
    on_exit fn ->
      Flub.unsub
      :timer.sleep(10)
    end
  end

  test "simple test" do
    channel = "simple"
    Flub.sub(channel)
    Flub.pub(:custom_data, channel)
    assert_receive(%Flub.Message{channel: ^channel, data: :custom_data})
  end

  test "remapping test" do
    channel = :remapping_test
    Flub.sub(channel, mapper: &(&1.data + 7))
    Flub.pub(1, channel)
    assert_receive(8)
  end

  test "unhappy remapping" do
    channel = :unhappy_remapping_test
    Flub.sub(channel, mapper: &(&1.data + 1))
    Flub.pub(:one, channel)
    Flub.pub(2, channel)
    assert_receive(3)
  end

  test "cancelled remapping" do
    channel = :cancelled_remapping_test
    Flub.sub(channel, mapper: fn %{data: :a} -> :a
                                                   _ -> Flub.cancel_pub
                                                end)
    Flub.pub(:a, channel)
    assert_receive(:a)
    Flub.pub(11, channel)
    refute_receive(_, 100)
  end

  test "multi subscribe gets a message for each match" do
    import Flub, only: [p: 1]
    Flub.sub(:test, filter: p(%{}))
    Flub.sub(:test, filter: p(%{a: _b}))
    Flub.pub(%{a: 1}, :test)
    assert_receive(%Flub.Message{channel: :test, data: %{a: 1}})
    assert_receive(%Flub.Message{channel: :test, data: %{a: 1}})
  end

  test "unsub shuts down the dispatcher" do
    Flub.sub(:test)
    Flub.unsub(:test)
    :timer.sleep(10)
    assert Flub.EtsHelper.Dispatchers.find(node(), :test) == :undefined
  end

  test "crashed dispatcher keeps subscribers" do
    Flub.sub(:test)
    Flub.EtsHelper.Dispatchers.find(node(), :test)
    |> Process.exit(:kill)
    :timer.sleep(10)
    Flub.pub(:msg, :test)
    assert_receive(%Flub.Message{channel: :test, data: :msg})
  end

  test "subscribe and unsub" do
    msg = {:hello, "this is", %{a: 'test'}}

    # make sure we get the message
    Flub.sub(:test_chan)
    Flub.pub(msg, :test_chan)
    assert_receive %Flub.Message{data: ^msg, channel: :test_chan}

    # make sure we _don't_ get the message
    Flub.unsub(:test_chan)
    Flub.pub(msg, :test_chan)
    refute_receive ^msg
  end

  test "unsub on process termination" do
    parent = self

    # spawn a blocking subscriber process
    pid = spawn fn ->
      Flub.sub(:test)
      send parent, :subscribed
      receive do
        :block -> :block
      end
    end

    # wait for subscription
    receive do
      :subscribed -> Process.monitor pid
    after 100 ->
      raise "subscribed msg not received"
    end

    # kill process and wait for :DOWN
    Process.exit pid, :kill
    receive do
      {:DOWN, _ref, :process, ^pid, :killed} -> :ok
    after 100 ->
      raise("monitor msg not received")
    end

    # wait for DOWN message to propogate and dispatcher to shut down:
    Process.sleep(10)
    assert Flub.EtsHelper.Dispatchers.find(node(), :test) == :undefined
  end

  defmodule TestStruct do
    defstruct value: 0, other: :default
  end
  test "pub filter" do
    import Flub, only: [p: 1]
    myvar = 10
    msg = %TestStruct{value: 15}
    msg2 = %TestStruct{value: 10}
    Flub.sub(:test_chan, filter: p(%TestStruct{value: ^myvar}))
    Flub.pub(msg, :test_chan)
    Flub.pub(msg2, :test_chan)


    refute_receive %Flub.Message{data: %TestStruct{value: 15}, channel: :test_chan}
    assert_receive %Flub.Message{data: %TestStruct{value: 10}, channel: :test_chan}
  end
  test "harmless other defaults" do
    import Flub, only: [p: 1]
    myvar = 15
    msg = %TestStruct{value: myvar, other: :custom}
    Flub.sub(:test_chan, filter: p(%TestStruct{value: ^myvar}))
    Flub.pub(msg, :test_chan)
    assert_receive %Flub.Message{data: %TestStruct{value: ^myvar, other: :custom}, channel: :test_chan}
  end

  # TODO: cross node test
end
