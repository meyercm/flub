defmodule Flub.App do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    # ensure that pg2 is up and running:
    {:ok, _pid} = :pg2.start

    Flub.EtsHelper.setup_tables
    children = [
      supervisor(Flub.NodeSync.Supervisor, []),
      supervisor(Flub.DispatcherSup, []),
    ]
    opts = [strategy: :one_for_one, name: Flub.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
