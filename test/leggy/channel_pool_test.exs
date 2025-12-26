defmodule Leggy.ChannelPoolTest do
  use ExUnit.Case
  alias Leggy.ChannelPool

  @opts [host: "localhost", username: "guest", password: "guest", pool_size: 2]

  test "starts the pool" do
    assert {:ok, _pid} = ChannelPool.start_link(@opts)
  end

  test "checkout returns error when not ready" do
    {:ok, pid} = ChannelPool.start_link(@opts)
    :sys.replace_state(pid, fn state -> %{state | status: :connecting} end)
    assert {:error, :not_ready} = ChannelPool.checkout(pid)
  end

  test "checkin returns channel to pool" do
    {:ok, pid} = ChannelPool.start_link(@opts)

    :sys.replace_state(pid, fn state ->
      %{state | status: :ready, pool: :queue.in(:ch, :queue.new())}
    end)

    assert {:ok, ref} = ChannelPool.checkout(pid)
    ChannelPool.checkin(pid, ref)
    assert true
  end

  test "overloaded waiting queue" do
    {:ok, pid} = ChannelPool.start_link(@opts)

    :sys.replace_state(pid, fn state ->
      %{
        state
        | status: :ready,
          pool: :queue.new(),
          max_waiters: 1,
          waiting: :queue.in(:from, :queue.new())
      }
    end)

    assert {:error, :overloaded} = ChannelPool.checkout(pid)
  end
end
