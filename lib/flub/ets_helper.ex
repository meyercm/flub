defmodule Flub.EtsHelper do
  @moduledoc false
  def setup_tables do
    Flub.EtsHelper.Subscribers.setup
  end
end
