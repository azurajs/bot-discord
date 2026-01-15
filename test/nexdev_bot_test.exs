defmodule AzuraJSTest do
  use ExUnit.Case
  doctest AzuraJS

  test "greets the world" do
    assert AzuraJS.hello() == :world
  end
end
