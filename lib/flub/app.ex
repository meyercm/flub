defmodule Flub.App do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Flub.EtsHelper.setup_tables
    children = [
      supervisor(Flub.DispatcherSup, []),
    ]
    :pg2.create(:flub_apps)
    :pg2.join(:flub_apps, self)
    opts = [strategy: :one_for_one, name: Flub.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
