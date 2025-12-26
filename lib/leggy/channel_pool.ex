defmodule Leggy.ChannelPool do
  @moduledoc false

  use GenServer

  require Logger

  @default_pool_size 4
  @default_max_waiters 100
  @reconnect_delay 1_000

  defmodule Ref do
    @enforce_keys [:channel]
    defstruct [:channel]
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec checkout(atom()) :: {:ok, Ref.t()} | {:error, term()}
  def checkout(server \\ __MODULE__) do
    GenServer.call(server, :checkout, 5_000)
  end

  @spec checkin(atom(), Ref.t()) :: :ok
  def checkin(server \\ __MODULE__, %Ref{} = ref) do
    GenServer.cast(server, {:checkin, ref})
  end

  @impl true
  def init(opts) do
    state = %{
      status: :connecting,
      conn: nil,
      conn_mon: nil,
      pool: :queue.new(),
      waiting: :queue.new(),
      pool_size: Keyword.get(opts, :pool_size, @default_pool_size),
      max_waiters: Keyword.get(opts, :max_waiters, @default_max_waiters),
      opts: opts
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    Logger.info("[Leggy.ChannelPool] Connecting to RabbitMQ...")

    with {:ok, conn} <- open_connection(state.opts),
         {:ok, channels} <- open_channels(conn, state.pool_size) do
      conn_mon = Process.monitor(conn.pid)

      pool =
        channels
        |> Enum.reduce(:queue.new(), fn ch, acc -> :queue.in(ch, acc) end)

      Logger.info("[Leggy.ChannelPool] Ready with #{state.pool_size} channels")

      {:noreply,
       %{
         state
         | status: :ready,
           conn: conn,
           conn_mon: conn_mon,
           pool: pool
       }}
    else
      {:error, reason} ->
        Logger.error("[Leggy.ChannelPool] Connection failed: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, %{state | status: :connecting}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{conn_mon: ref} = state) do
    Logger.error("[Leggy.ChannelPool] Connection DOWN: #{inspect(reason)}")
    fail_waiters(state.waiting, :connection_lost)
    schedule_reconnect()

    {:noreply,
     %{
       state
       | status: :connecting,
         conn: nil,
         conn_mon: nil,
         pool: :queue.new(),
         waiting: :queue.new()
     }}
  end

  @impl true
  def handle_call(:checkout, _from, %{status: :connecting} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  @impl true
  def handle_call(:checkout, from, %{pool: pool, waiting: waiting} = state) do
    case :queue.out(pool) do
      {{:value, ch}, pool2} ->
        {:reply, {:ok, %Ref{channel: ch}}, %{state | pool: pool2}}

      {:empty, _} ->
        if :queue.len(waiting) >= state.max_waiters do
          {:reply, {:error, :overloaded}, state}
        else
          {:noreply, %{state | waiting: :queue.in(from, waiting)}}
        end
    end
  end

  @impl true
  def handle_cast({:checkin, %Ref{channel: ch}}, state) do
    ch =
      if alive?(ch) do
        ch
      else
        reopen_channel(state.conn)
      end

    case ch do
      {:error, reason} ->
        Logger.error("[Leggy.ChannelPool] Failed to reopen channel: #{inspect(reason)}")
        {:noreply, state}

      ch ->
        {:noreply, dispatch_channel(state, ch)}
    end
  end

  defp dispatch_channel(%{waiting: waiting} = state, ch) do
    case :queue.out(waiting) do
      {{:value, from}, waiting2} ->
        GenServer.reply(from, {:ok, %Ref{channel: ch}})
        %{state | waiting: waiting2}

      {:empty, _} ->
        %{state | pool: :queue.in(ch, state.pool)}
    end
  end

  defp fail_waiters(waiting, reason) do
    Enum.each(:queue.to_list(waiting), fn from ->
      GenServer.reply(from, {:error, reason})
    end)
  end

  defp schedule_reconnect do
    Process.send_after(self(), :connect, @reconnect_delay)
  end

  defp alive?(%AMQP.Channel{pid: pid}), do: is_pid(pid) and Process.alive?(pid)

  defp alive?(_), do: false

  defp reopen_channel(nil), do: {:error, :no_connection}

  defp reopen_channel(conn), do: AMQP.Channel.open(conn)

  defp open_channels(conn, n) do
    Enum.reduce_while(1..n, [], fn _, acc ->
      case AMQP.Channel.open(conn) do
        {:ok, ch} -> {:cont, [ch | acc]}
        {:error, r} -> {:halt, {:error, r}}
      end
    end)
    |> case do
      {:error, _} = err -> err
      channels -> {:ok, channels}
    end
  end

  defp open_connection(opts) do
    AMQP.Connection.open(
      host: Keyword.fetch!(opts, :host),
      username: Keyword.get(opts, :username, "guest"),
      password: Keyword.get(opts, :password, "guest"),
      port: Keyword.get(opts, :port, 5672),
      virtual_host: Keyword.get(opts, :virtual_host, "/"),
      heartbeat: Keyword.get(opts, :heartbeat, 10)
    )
  end
end
