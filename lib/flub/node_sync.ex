defmodule Flub.NodeSync do
  @moduledoc """
  Flub.NodeSync is a helper to ensure that :pg2 groups remain sync'd between
  nodes in a distributed deployment.  The methods here are automatically engaged
  when subscribing to remote nodes to minimize the risk of remotely published
  messages not being propogated to the local node.
  """
  use GenServer
  ##############################
  # API
  ##############################

  @impl GenServer
  def init(arg), do: {:ok, arg}

  @doc """
  Request that the connection to `node` be maintained, via `Node.ping` and
  `Node.monitor`.
  """
  def maintain_connection(node) do
    Flub.NodeSync.Worker.start(node)
  end

  @doc """
  Stop the automatic connecion maintenence for `node`. This method does *not*
  call Node.disconnect, but simply stops attempting to monitor and resurrect
  the connection in case of failures.
  """
  def release_connection(node) do
    Flub.NodeSync.Worker.release(node)
  end

end
