defmodule AzuraJS.Gemini do
  require Logger

  @model "gemini-2.5-flash"
  @base "https://generativelanguage.googleapis.com/v1beta/models"
  @timeout 120_000

  def request(prompt) when is_binary(prompt) do
    api_key = System.get_env("GEMINI_API_KEY")

    if api_key == "" do
      {:error, :missing_api_key}
    else
      url = "#{@base}/#{@model}:generateContent?key=#{api_key}"
      lang = detect_lang(prompt)
      system_instruction = build_system_instruction(lang)

      body = %{
        "systemInstruction" => %{"parts" => [%{"text" => system_instruction}]},
        "contents" => [%{"role" => "user", "parts" => [%{"text" => prompt}]}],
        "tools" => [%{"googleSearch" => %{}}]
      }

      headers = [{"Content-Type", "application/json"}]

      case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @timeout) do
        {:ok, %HTTPoison.Response{status_code: code, body: resp}} when code in 200..299 ->
          parse_response(resp)

        {:ok, %HTTPoison.Response{status_code: code, body: resp}} ->
          Logger.error("Gemini request failed: %{status: #{code}}")
          {:error, %{status: code, body: resp}}

        {:error, reason} ->
          Logger.error("Gemini request error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp build_system_instruction(lang) do
    base = """
    You are an AI assistant for the AzuraJS Discord server.
    You must ONLY answer questions related to the AzuraJS framework.
    Do NOT respond to topics unrelated to AzuraJS.
    ALL answers MUST be strictly based on the official AzuraJS documentation:
    https://azura.js.org/docs/{lang}/ (where {lang} is the language of the user query, "pt" or "en" only).
    Do NOT create, assume, or infer any behavior, API, or feature that is not explicitly documented.
    Only use code snippets, examples, and explanations that exist in the official documentation.
    When helping a user, always follow this response format:
    Hi! 👋
    You can find this feature in the official documentation at:
    {full_documentation_link}

    Summary:
    A brief and clear explanation copied or summarized directly from the official documentation, without adding new information.
    The documentation link MUST be as specific as possible, including the exact #section or anchor where the feature is documented when available.
    Always respond using the same language as the user. Detect the language from the user's prompt and use "pt" for Portuguese or "en" for English.
    If the user's language cannot be detected, default to "en".
    If the documentation does not contain the requested information, reply in the user's language with:
    "I can only answer questions about AzuraJS. I couldn't find that information in the documentation."
    """

    String.replace(base, "{lang}", lang)
  end

  defp detect_lang(prompt) when is_binary(prompt) do
    text = String.downcase(prompt)

    cond do
      Regex.match?(
        ~r/\b(oi|ol[áa]|obrigad[oa]|por favor|tudo bem|bom dia|boa tarde|boa noite)\b/u,
        text
      ) ->
        "pt"

      Regex.match?(~r/[áéíóúãõâêôç]/u, text) ->
        "pt"

      true ->
        "en"
    end
  end

  defp parse_response(body) when is_binary(body) do
    with {:ok, decoded} <- Jason.decode(body) do
      text =
        decoded
        |> extract_text_from_decoded()
        |> String.trim()

      Logger.debug("Gemini returned text: #{inspect(text)}")
      {:ok, text}
    else
      err -> {:error, err}
    end
  end

  defp extract_text_from_decoded(%{"candidates" => candidates}) when is_list(candidates) do
    candidates
    |> Enum.map(&maybe_get_candidate_text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp extract_text_from_decoded(%{"output" => output}) when is_list(output) do
    output
    |> Enum.flat_map(&extract_from_output_item/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp extract_text_from_decoded(%{"output_text" => out}) when is_binary(out), do: out
  defp extract_text_from_decoded(%{"text" => t}) when is_binary(t), do: t
  defp extract_text_from_decoded(other) when is_map(other), do: inspect(other)
  defp extract_text_from_decoded(other), do: to_string(other)

  defp maybe_get_candidate_text(%{"content" => %{"parts" => parts}}) when is_list(parts) do
    parts |> Enum.map(&(&1["text"] || "")) |> Enum.join("\n")
  end

  defp maybe_get_candidate_text(%{"content" => content}) when is_map(content) do
    case content["parts"] do
      parts when is_list(parts) -> Enum.map_join(parts, "\n", &(&1["text"] || ""))
      _ -> inspect(content)
    end
  end

  defp maybe_get_candidate_text(%{"text" => t}) when is_binary(t), do: t
  defp maybe_get_candidate_text(_), do: ""

  defp extract_from_output_item(%{"content" => content}) when is_list(content) do
    content
    |> Enum.map(fn
      %{"text" => t} when is_binary(t) -> t
      %{"type" => _, "text" => t} when is_binary(t) -> t
      _ -> ""
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_from_output_item(%{"content" => %{"parts" => parts}}) when is_list(parts) do
    parts |> Enum.map(&(&1["text"] || "")) |> Enum.reject(&(&1 == ""))
  end

  defp extract_from_output_item(%{"text" => t}) when is_binary(t), do: [t]
  defp extract_from_output_item(_), do: []
end
