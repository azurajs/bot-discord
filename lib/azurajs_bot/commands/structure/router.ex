defmodule AzuraJS.Commands.Structure.Router do
  @prefix "!"

  alias AzuraJS.Commands.{
    Ping,
    Ticket
  }

  @commands %{
    Ping.name() => Ping,
    Ticket.name() => Ticket
  }

  def dispatch(%{content: content} = msg) do
    if String.starts_with?(content, @prefix) do
      whitout_prefix = String.trim_leading(content, @prefix)
      [cmd | _] = String.split(whitout_prefix, " ")

      case Map.get(@commands, cmd) do
        nil -> :noop
        module -> module.execute(msg)
      end
    else
      :noop
    end
  end
end
