defmodule Leggy do
  @moduledoc """
  RabbitMQ messaging library with schema contracts and channel pooling.
  """

  alias Leggy.{Codec, Validator}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @leggy_config [
        host: Keyword.fetch!(opts, :host),
        username: Keyword.get(opts, :username, "guest"),
        password: Keyword.get(opts, :password, "guest"),
        pool_size: Keyword.get(opts, :pool_size, 4)
      ]

      @leggy_pool Module.concat(__MODULE__, ChannelPool)

      def child_spec(_arg \\ []) do
        %{
          id: @leggy_pool,
          start:
            {Leggy.ChannelPool, :start_link, [Keyword.put(@leggy_config, :name, @leggy_pool)]},
          type: :supervisor
        }
      end

      @spec prepare(module()) :: :ok | {:error, term()}
      def prepare(schema) do
        with_channel(fn ch ->
          exchange = exchange(schema)
          queue = queue(schema)
          dlx = dlx(schema)
          dlq = dlq(schema)

          # Main exchange
          AMQP.Exchange.declare(ch, exchange, :direct, durable: true)

          # Dead-letter exchange
          AMQP.Exchange.declare(ch, dlx, :direct, durable: true)

          # Main queue with DLX
          AMQP.Queue.declare(
            ch,
            queue,
            durable: true,
            arguments: [
              {"x-dead-letter-exchange", :longstr, dlx},
              {"x-dead-letter-routing-key", :longstr, dlq}
            ]
          )

          # Dead-letter queue
          AMQP.Queue.declare(ch, dlq, durable: true)

          # Bindings
          AMQP.Queue.bind(ch, queue, exchange, routing_key: queue)
          AMQP.Queue.bind(ch, dlq, dlx, routing_key: dlq)

          :ok
        end)
      end

      @spec publish(struct()) :: :ok | {:error, term()}
      def publish(struct) do
        schema = struct.__struct__
        payload = Codec.encode!(struct)

        with_channel(fn ch ->
          AMQP.Basic.publish(
            ch,
            schema.__leggy_exchange__(),
            schema.__leggy_queue__(),
            payload,
            persistent: true
          )
        end)
      end

      @spec get(module()) :: {:ok, struct()} | {:error, term()}
      def get(schema) do
        with_channel(fn ch ->
          case AMQP.Basic.get(ch, schema.__leggy_queue__(), no_ack: false) do
            {:ok, payload, meta} ->
              with {:ok, map} <- Codec.decode(payload),
                   {:ok, struct} <- Validator.cast(schema, map) do
                AMQP.Basic.ack(ch, meta.delivery_tag)
                {:ok, struct}
              else
                {:error, reason} ->
                  AMQP.Basic.nack(ch, meta.delivery_tag, requeue: false)
                  {:error, reason}
              end

            {:empty, _meta} ->
              {:error, :empty}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end

      @spec cast(module(), map() | keyword()) :: {:ok, struct()} | {:error, term()}
      def cast(schema, data) do
        Validator.cast(schema, data)
      end

      # used to tests snecarios with direct channel access
      def with_channel_public(fun) when is_function(fun, 1), do: with_channel(fun)

      defp with_channel(fun) when is_function(fun, 1) do
        pool = @leggy_pool

        case Leggy.ChannelPool.checkout(pool) do
          {:ok, ch_ref} ->
            try do
              fun.(ch_ref.channel)
            after
              Leggy.ChannelPool.checkin(pool, ch_ref)
            end

          {:error, reason} ->
            {:error, reason}
        end
      end

      defp exchange(schema), do: schema.__leggy_exchange__()
      defp queue(schema), do: schema.__leggy_queue__()

      defp dlx(schema), do: exchange(schema) <> "_dlx"
      defp dlq(schema), do: queue(schema) <> "_dlq"
    end
  end
end
