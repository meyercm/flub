defmodule Flub.App do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Flub.EtsHelper.setup_tables
    children = [
      %{id: :pg, start: {:pg, :start_link, []}},
      {Flub.NodeSync.Supervisor, []},
      {Flub.DispatcherSup, []},
    ]
    opts = [strategy: :one_for_one, name: Flub.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
