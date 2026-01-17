defmodule AzuraJS.MnnIA do
  @moduledoc false

  @default_model "gpt-4o-azura"
  @timeout 180_000

  def request(prompt) when is_binary(prompt) do
    api_key = System.get_env("MNN_API_KEY") || ""
    api_base = System.get_env("MNN_API_BASE") || "https://api.mnnai.ru/v1"
    url = String.trim_trailing(api_base, "/") <> "/responses"

    system_instruction = """
    SYSTEM:

    Você é o Assistente Oficial do servidor Discord da AzuraJS. 👋✨
    Sua função: responder **apenas** perguntas sobre o framework AzuraJS e **apenas** com informação que exista explicitamente na documentação oficial.

    PERSONA (tom)
    - Amigável, claro e "bem dahora": curto, objetivo, com emojis sutis.
    - Profissional: não inventa, não supõe, não extrapola.
    - Sempre cite a URL exata que serviu de fonte.

    SOURCE RULES (obrigatórias)
    1. Todas as respostas DEVEM SER baseadas exclusivamente nas páginas listadas em `allowed_routes`. Nenhuma outra fonte é permitida.
    2. Não crie, presuma ou infera APIs, comportamentos, parâmetros ou exemplos que não estejam explicitamente documentados nas rotas permitidas.
    3. Se a resposta requerer código, use apenas trechos EXATOS copiados ou estritamente paraphraseados da documentação. Marque blocos de código com ```js```/```ts```/```ex``` conforme o exemplo do site.
    4. Toda resposta precisa incluir **apenas uma** URL do `allowed_routes` que contenha a informação usada. Coloque a URL logo após o cabeçalho inicial.
    5. Se a pergunta NÃO estiver coberta por nenhuma rota, responda exatamente:
    "Sorry — this question is outside the official AzuraJS documentation. See: https://azura.js.org/docs/{lang}/"
    6. Quando for enviar o link da documentação utilize a linguagem /docs/en/ ou /docs/pt/ conforme o idioma do texto.

    LANGUAGE
    - Detecte e responda no mesmo idioma do usuário (`pt` ou `en`).

    RESPONSE FORMAT (ONLY for real questions)
    Hi! 👋
    You can find this feature in the official documentation at:
    {full_documentation_link_from_allowed_routes}

    Summary:
    {uma explicação curta (1–3 parágrafos) copiada ou estritamente paraphraseada da página citada — sem adicionar nada novo}

    Example:
    {apenas se a página fornecer um exemplo em código — cole o trecho exato entre fences de código}
    """

    allowed_routes_en = [
      "https://azura.js.org/docs/en/",
      "https://azura.js.org/docs/en/installation",
      "https://azura.js.org/docs/en/quick-start",
      "https://azura.js.org/docs/en/javascript-usage",
      "https://azura.js.org/docs/en/configuration",
      "https://azura.js.org/docs/en/controllers",
      "https://azura.js.org/docs/en/routing",
      "https://azura.js.org/docs/en/decorators",
      "https://azura.js.org/docs/en/middleware",
      "https://azura.js.org/docs/en/validation",
      "https://azura.js.org/docs/en/cookies",
      "https://azura.js.org/docs/en/logger",
      "https://azura.js.org/docs/en/cors",
      "https://azura.js.org/docs/en/rate-limiting",
      "https://azura.js.org/docs/en/proxy",
      "https://azura.js.org/docs/en/cluster-mode",
      "https://azura.js.org/docs/en/error-handling",
      "https://azura.js.org/docs/en/swagger",
      "https://azura.js.org/docs/en/custom-servers",
      "https://azura.js.org/docs/en/type-extensions",
      "https://azura.js.org/docs/en/modular-imports",
      "https://azura.js.org/docs/en/typescript-support",
      "https://azura.js.org/docs/en/performance",
      "https://azura.js.org/docs/en/examples"
    ]

    allowed_routes_pt = Enum.map(allowed_routes_en, fn r -> String.replace(r, "/en/", "/pt/") end)
    allowed_routes = allowed_routes_en ++ allowed_routes_pt

    lang = detect_lang(prompt)
    route = choose_route(prompt, allowed_routes, lang)
    doc_text = fetch_doc(route)

    user_source = """
    SOURCE_URL: #{route}

    SOURCE_CONTENT_BEGIN
    #{String.slice(doc_text, 0, 200_000)}
    SOURCE_CONTENT_END

    USER_QUESTION:
    #{prompt}
    """

    input_messages = [
      %{"role" => "system", "content" => system_instruction},
      %{"role" => "user", "content" => user_source}
    ]

    body =
      %{
        "model" => @default_model,
        "input" => input_messages,
        "temperature" => 0.0,
        "max_output_tokens" => 800,
        "tools" => [%{ "type" => "web_search_preview" }]
      }
      |> Jason.encode!()

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer " <> api_key}
    ]

    opts = [recv_timeout: @timeout, hackney: [inet6: false]]

    case HTTPoison.post(url, body, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: code, body: resp_body}} when code in 200..299 ->
        parse_response_body(resp_body)

      {:ok, %HTTPoison.Response{status_code: code, body: resp_body}} ->
        {:error, %{status: code, body: resp_body}}

      {:error, %HTTPoison.Error{} = err} ->
        {:error, err}

      other ->
        {:error, other}
    end
  end

  defp detect_lang(text) when is_binary(text) do
    regex =
      ~r/\b(olá|oi|como|qual|pra|por que|instalação|configuração|middleware|controllers|rotas|exemplo|boa tarde|bom dia|boa noite)\b/i

    if Regex.match?(regex, text), do: "pt", else: "en"
  end

  defp choose_route(prompt, routes, lang) do
    filtered =
      Enum.filter(routes, fn r ->
        String.ends_with?(r, "/#{lang}/") or String.contains?(r, "/#{lang}/")
      end)

    down = String.downcase(prompt)

    match =
      Enum.find(filtered, fn r ->
        path = URI.parse(r).path || ""
        segments = String.split(path, "/", trim: true)

        Enum.any?(segments, fn seg ->
          seg != "docs" and seg != lang and String.contains?(down, String.downcase(seg))
        end)
      end)

    case match do
      nil -> "https://azura.js.org/docs/#{lang}/"
      m -> m
    end
  end

  defp fetch_doc(url) when is_binary(url) do
    headers = [{"User-Agent", "AzuraJS-Gemini/1.0"}]
    opts = [recv_timeout: 10_000, hackney: [inet6: false]]

    case HTTPoison.get(url, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> body
      _ -> ""
    end
  end

  defp parse_response_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> extract_text(decoded)
      {:ok, _} -> {:error, :unexpected_format}
      {:error, _} = err -> err
    end
  end

  defp extract_text(%{"output_text" => t}) when is_binary(t), do: {:ok, String.trim(t)}

  defp extract_text(%{"choices" => choices}) when is_list(choices) do
    texts =
      choices
      |> Enum.flat_map(&text_pieces_from_choice/1)
      |> Enum.reject(&(&1 in [nil, ""]))

    case texts do
      [] -> {:error, :no_text_found}
      _ -> {:ok, Enum.join(texts, "\n\n") |> String.trim()}
    end
  end

  defp extract_text(%{"output" => output}) when is_list(output) do
    texts =
      output
      |> Enum.flat_map(&text_pieces_from_output_item/1)
      |> Enum.reject(&(&1 in [nil, ""]))

    case texts do
      [] -> {:error, :no_text_found}
      _ -> {:ok, Enum.join(texts, "\n\n") |> String.trim()}
    end
  end

  defp extract_text(%{"message" => msg}) when is_map(msg) do
    case extract_text_from_message(msg) do
      nil -> {:error, :no_text_found}
      text -> {:ok, String.trim(text)}
    end
  end

  defp extract_text(%{"text" => t}) when is_binary(t), do: {:ok, String.trim(t)}
  defp extract_text(_), do: {:error, :unexpected_format}

  defp text_pieces_from_choice(%{"message" => msg}) when is_map(msg),
    do: List.wrap(extract_text_from_message(msg))

  defp text_pieces_from_choice(%{"text" => text}) when is_binary(text), do: [text]
  defp text_pieces_from_choice(_), do: []

  defp text_pieces_from_output_item(item) when is_map(item) do
    cond do
      is_binary(Map.get(item, "text")) ->
        [Map.get(item, "text")]

      is_binary(Map.get(item, "content")) ->
        [Map.get(item, "content")]

      is_list(Map.get(item, "content")) ->
        Map.get(item, "content")
        |> Enum.map(&maybe_text_from_content/1)
        |> Enum.reject(&(&1 in [nil, ""]))

      Map.has_key?(item, "message") and is_map(item["message"]) ->
        extract_text_from_message(item["message"]) |> List.wrap()

      true ->
        []
    end
  end

  defp text_pieces_from_output_item(_), do: []

  defp extract_text_from_message(%{"content" => content}) when is_binary(content), do: content

  defp extract_text_from_message(%{"content" => content}) when is_list(content) do
    content
    |> Enum.map(&maybe_text_from_content/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp extract_text_from_message(%{"text" => t}) when is_binary(t), do: t
  defp extract_text_from_message(_), do: nil

  defp maybe_text_from_content(%{"text" => t}) when is_binary(t), do: t
  defp maybe_text_from_content(t) when is_binary(t), do: t
  defp maybe_text_from_content(_), do: nil
end
