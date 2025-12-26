defmodule Leggy.ConsumerTask do
  @moduledoc """
  Crash-only RabbitMQ consumer using a dedicated connection and channel.
  """

  require Logger
  alias Leggy.{Codec, Validator}

  def start_link(consumer, repo, schema) do
    Task.start_link(fn ->
      consume_loop(consumer, repo, schema)
    end)
  end

  defp consume_loop(consumer, repo, schema) do
    {:ok, conn} = AMQP.Connection.open(repo.config())
    {:ok, ch} = AMQP.Channel.open(conn)

    Process.monitor(conn.pid)

    :ok = AMQP.Basic.qos(ch, prefetch_count: 10)
    {:ok, _} = AMQP.Basic.consume(ch, schema.__queue__(), nil, no_ack: false)

    receive_loop(consumer, ch, schema)
  end

  defp receive_loop(consumer, ch, schema) do
    receive do
      {:basic_deliver, payload, meta} ->
        handle_delivery(consumer, ch, schema, payload, meta)
        receive_loop(consumer, ch, schema)

      {:basic_cancel, _} ->
        Logger.warning("Consumer cancelled by broker")
        {:error, {:consumer_cancelled, "Consumer cancelled by broker"}}

      {:DOWN, _, :process, _, _} ->
        Logger.error("Connection lost")
        {:error, {:connection_lost, "Connection lost"}}
    end
  end

  defp handle_delivery(consumer, ch, schema, payload, meta) do
    with {:ok, map} <- Codec.decode(payload),
         {:ok, struct} <- Validator.cast(schema, map),
         :ok <- consumer.handle_message(struct) do
      AMQP.Basic.ack(ch, meta.delivery_tag)
    else
      error ->
        AMQP.Basic.reject(ch, meta.delivery_tag, requeue: false)
        {:error, {:message_failed, error}}
    end
  end
end
