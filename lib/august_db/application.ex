defmodule AugustDb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the CommitLog device genserver
      CommitLog,
      # Start Memtable Size genserver
      Memtable.Sizer,
      # Start the SSTable Index agent
      {SSTable.Index, %{}},
      # Start the Cuckoo Filter agent
      {CuckooFilter, %{}},
      # Make sure commit log exists, old entries are written into SSTable, etc.
      {Task, fn -> Startup.init() end},
      # Start periodic SSTable compaction
      SSTable.Compaction.Periodic,
      # Start the memory monitor (prints to :stdout)
      MemoryMonitor,
      # Start the Telemetry supervisor
      AugustDbWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: AugustDb.PubSub},
      # Start the Endpoint (http/https)
      AugustDbWeb.Endpoint
      # Start a worker by calling: AugustDb.Worker.start_link(arg)
      # {AugustDb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AugustDb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AugustDbWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
