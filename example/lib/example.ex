defmodule Example do
  alias Example.Schemas.RabbitSchema

  def start_pool() do
    {:ok, _pid} = Supervisor.start_link([Example.RabbitRepo], strategy: :one_for_one)
  end

  def prepare(), do: Example.LeggyRepo.prepare(RabbitSchema)

  def producer() do
    {:ok, msg} =
      Example.LeggyRepo.cast(RabbitSchema, %{
        user: "r2d2",
        ttl: 5,
        valid?: true,
        requested_at: DateTime.utc_now()
    })

    Example.LeggyRepo.publish(msg)
  end

  def consumer() do
    case Example.LeggyRepo.get(RabbitSchema) do
      {:ok, struct} ->
        IO.inspect(struct, label: "Received message")
        :ok

      {:error, reason} ->
        IO.inspect(reason, label: "Error to get message")
        :error
    end
  end
end
