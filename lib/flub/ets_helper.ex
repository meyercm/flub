defmodule Flub.EtsHelper do
  def setup_tables do
     Flub.EtsHelper.Subscribers.setup
     Flub.EtsHelper.Dispatchers.setup
  end
end
