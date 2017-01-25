defmodule Flub.EtsHelper do
  @moduledoc false
  def setup_tables do
     Flub.EtsHelper.Subscribers.setup
     Flub.EtsHelper.Dispatchers.setup
  end
end
