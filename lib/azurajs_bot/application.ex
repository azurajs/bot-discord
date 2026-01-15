defmodule AzuraJS.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AzuraJS.Consumer,
      AzuraJS.TicketManager
    ]

    opts = [strategy: :one_for_one, name: AzuraJS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
