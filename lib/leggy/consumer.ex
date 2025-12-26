defmodule Leggy.Consumer do
  @moduledoc false

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    concurrency = Keyword.get(opts, :concurrency, 1)

    quote do
      use Supervisor

      def start_link(_) do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      def init(:ok) do
        children =
          for i <- 1..unquote(concurrency) do
            %{
              id: {Leggy.ConsumerTask, i},
              start: {
                Leggy.ConsumerTask,
                :start_link,
                [__MODULE__, unquote(repo), unquote(schema)]
              },
              restart: :permanent
            }
          end

        Supervisor.init(children, strategy: :one_for_one)
      end

      @callback handle_message(struct()) :: :ok
    end
  end
end
