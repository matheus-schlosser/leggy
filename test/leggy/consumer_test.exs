defmodule Leggy.ConsumerTest do
  use ExUnit.Case
  require Leggy.Consumer

  defmodule DummyConsumer do
    use Leggy.Consumer, repo: DummyRepo, schema: DummySchema, concurrency: 2
    def handle_message(_), do: :ok
  end

  test "start_link starts supervisor" do
    assert {:ok, pid} = DummyConsumer.start_link([])
    assert is_pid(pid)
  end
end
