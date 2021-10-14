defmodule Flub.App do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Flub.EtsHelper.setup_tables
    :ok = case :pg.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> {:error, error}
    end
    children = [
      {Flub.NodeSync.Supervisor, []},
      {Flub.DispatcherSup, []},
    ]
    opts = [strategy: :one_for_one, name: Flub.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
