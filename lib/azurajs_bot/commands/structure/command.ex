defmodule AzuraJS.Command do
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback execute(map) :: any()
end
