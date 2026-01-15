import Config

if Code.ensure_loaded?(Dotenvy) do
  Dotenvy.source!([".env"])
else
  env_path = Path.expand("../.env", __DIR__)

  if File.exists?(env_path) do
    File.stream!(env_path)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.each(fn line ->
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          value =
            value
            |> String.trim()
            |> String.trim_leading("\"")
            |> String.trim_trailing("\"")

          System.put_env(key, value)

        _ ->
          :ok
      end
    end)
  end
end

config :nostrum,
  token: System.get_env("DISCORD_TOKEN")
