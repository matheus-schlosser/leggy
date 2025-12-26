defmodule LeggyTest do
  use ExUnit.Case
  require Leggy

  defmodule EmailChangeMessage do
    use Leggy.Schema

    schema "test_exchange", "test_queue" do
      field(:user, :string)
      field(:ttl, :integer)
      field(:valid?, :boolean)
      field(:requested_at, :datetime)
    end
  end

  defmodule RabbitRepo do
    use Leggy,
      host: "localhost",
      username: "guest",
      password: "guest",
      pool_size: 1
  end

  setup_all do
    start_supervised!(RabbitRepo)
    :ok = RabbitRepo.prepare(EmailChangeMessage)

    RabbitRepo.with_channel_public(fn ch ->
      AMQP.Queue.purge(ch, EmailChangeMessage.__leggy_queue__())
      AMQP.Queue.purge(ch, EmailChangeMessage.__leggy_queue__() <> "_dlq")
    end)

    :ok
  end

  test "defines child_spec correctly" do
    spec = RabbitRepo.child_spec()

    args =
      spec.start
      |> elem(2)
      |> List.first()

    assert args[:host] == "localhost"
    assert args[:username] == "guest"
    assert args[:password] == "guest"
    assert args[:pool_size] == 1
  end

  test "prepare returns :ok" do
    assert :ok = RabbitRepo.prepare(EmailChangeMessage)
  end

  test "returns error when queue is empty" do
    assert {:error, :empty} = RabbitRepo.get(EmailChangeMessage)
  end

  test "publish and get message from queue" do
    requested_at = DateTime.utc_now() |> DateTime.to_iso8601()

    {:ok, msg} =
      RabbitRepo.cast(EmailChangeMessage, %{
        user: "r2d2",
        ttl: 2,
        valid?: true,
        requested_at: requested_at
      })

    :ok = RabbitRepo.publish(msg)
    Process.sleep(50)
    result = RabbitRepo.get(EmailChangeMessage)

    assert {:ok, %EmailChangeMessage{} = schema} = result

    assert schema.user == "r2d2"
    assert schema.ttl == 2
    assert schema.valid? == true
    assert DateTime.to_iso8601(schema.requested_at) == requested_at
  end

  test "publish invalid message and get error" do
    struct = %EmailChangeMessage{
      user: "r2d2",
      ttl: 2,
      valid?: 5,
      requested_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ok = RabbitRepo.publish(struct)

    Process.sleep(50)

    result = RabbitRepo.get(EmailChangeMessage)
    assert match?({:error, {:invalid_type, :valid?, :not_boolean}}, result)
  end

  #TODO: Check why is intermitently failing
  test "valid message is published and consumed, an invalid one is sent to DLQ" do
    RabbitRepo.with_channel_public(fn ch ->
      AMQP.Queue.purge(ch, EmailChangeMessage.__leggy_queue__())
      AMQP.Queue.purge(ch, EmailChangeMessage.__leggy_queue__() <> "_dlq")
    end)

    # Create a valid message
    {:ok, valid_struct} =
      RabbitRepo.cast(EmailChangeMessage, %{
        user: "r2d2",
        ttl: 5,
        valid?: true,
        requested_at: DateTime.utc_now()
      })

    # Publish a valid message
    :ok = RabbitRepo.publish(valid_struct)
    Process.sleep(50)

    # Consume → should return a valid struct
    result = RabbitRepo.get(EmailChangeMessage)

    assert {:ok, %EmailChangeMessage{}} = result

    # Create an invalid message
    invalid_struct =
      Map.put(valid_struct, :valid?, "123")

    # Publish an invalid message
    :ok = RabbitRepo.publish(invalid_struct)
    Process.sleep(300)

    # Consume fails → the message should be sent to the DLQ
    assert {:error, {:invalid_type, :valid?, :not_boolean}} =
             RabbitRepo.get(EmailChangeMessage)

    # Consume directly from the DLQ to verify
    dlq_queue =
      EmailChangeMessage.__leggy_queue__() <> "_dlq"

    RabbitRepo.with_channel_public(fn ch ->
      result =
        AMQP.Basic.get(ch, dlq_queue, no_ack: true)

      assert {:ok, payload, _meta} = result
      {:ok, map} = Leggy.Codec.decode(payload)

      assert map.valid? == "123"
    end)
  end

  test "allows concurrency up to pool_size" do
    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          RabbitRepo.with_channel_public(fn _ch -> :ok end)
        end)
      end

    assert Enum.all?(Task.await_many(tasks), &(&1 == :ok))
  end
end
