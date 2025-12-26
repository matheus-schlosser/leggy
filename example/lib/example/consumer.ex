defmodule Example.Consumer do
  @moduledoc """
  Example of a Leggy consumer module (optional).

  This module demonstrates how to use Leggy.Consumer to process messages from RabbitMQ queues using a schema and repo.
  The `handle_message/1` callback is called for each received message and should contain your business logic.

  Using a consumer module is optional. You can consume messages directly via your repo and schema if you prefer not to use this pattern.

  Usage:
    - Configure repo and schema.
    - Implement `handle_message/1` to process messages.
    - Set concurrency for parallel consumers.
  """
  use Leggy.Consumer,
    repo: Example.LeggyRepo,
    schema: Example.Schemas.RabbitSchema,
    concurrency: 2

  @impl true
  def handle_message(%Example.Schemas.RabbitSchema{} = msg) do
    IO.inspect(msg, label: "Mensagem recebida")
    :ok
  end
end
