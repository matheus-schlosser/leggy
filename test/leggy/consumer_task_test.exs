defmodule Leggy.ConsumerTaskTest do
  use ExUnit.Case
  alias Leggy.ConsumerTask

  test "start_link starts a task" do
    assert {:ok, pid} =
             ConsumerTask.start_link(self(), %{config: fn -> [] end}, %{__queue__: fn -> "q" end})

    assert is_pid(pid)
  end
end
