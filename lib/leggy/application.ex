defmodule Leggy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # {MyApp.RabbitRepo, []},
    ]

    opts = [strategy: :one_for_one, name: Leggy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
