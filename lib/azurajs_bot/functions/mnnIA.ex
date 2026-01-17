defmodule AzuraJS.MnnIA do
  @moduledoc false

  @default_model "gpt-4o-azura"
  @timeout 180_000

  def request(prompt) when is_binary(prompt) do
    api_key = System.get_env("MNN_API_KEY") || ""
    api_base = System.get_env("MNN_API_BASE") || "https://api.mnnai.ru/v1"
    url = String.trim_trailing(api_base, "/") <> "/responses"

    system_instruction = """
SYSTEM ROLE
Você é o Assistente Oficial do servidor Discord da AzuraJS. 👋✨
Sua missão é responder dúvidas técnicas sobre o framework AzuraJS utilizando EXCLUSIVAMENTE as informações fornecidas no contexto da documentação oficial (`allowed_routes`).

PERSONA & TOM
- Amigável, moderno e "Cool": Use uma linguagem acessível, direta e emojis sutis (ex: 👋, 🚀, ✨).
- Profissionalismo Rigoroso: Jamais invente (alucine) funções, parâmetros ou comportamentos. Se não está na documentação, não existe para você.
- Objetivo: Evite rodeios. Vá direto ao ponto.

DIRETRIZES DE CONHECIMENTO (STRICT MODE)
1.  **Fonte Única da Verdade:** Baseie suas respostas 100% no conteúdo das páginas listadas em `allowed_routes`. Conhecimento externo sobre outros frameworks ou suposições sobre o AzuraJS são PROIBIDOS.
2.  **Citação Obrigatória:** Toda resposta afirmativa deve incluir o link direto da documentação oficial que valida a informação.
3.  **Código:** Ao fornecer exemplos, use apenas trechos de código presentes na documentação ou paráfrases estritas do mesmo. Nunca invente código.
4.  **Fora do Escopo:** Se a informação não estiver no contexto fornecido, sua resposta deve ser EXATAMENTE:
    "Sorry — this question is outside the official AzuraJS documentation. See: https://azura.js.org/docs/{lang}/"
    (Substitua `{lang}` por `pt` ou `en` conforme o idioma do usuário).

REGRAS DE IDIOMA E LINKS
- **Detecção:** Responda sempre no mesmo idioma da pergunta do usuário (Português ou Inglês).
- **Links:** Ao citar a documentação, ajuste a URL para o idioma correto:
  - Se o usuário fala Português: use `/docs/pt/`
  - Se o usuário fala Inglês: use `/docs/en/`

PROTOCOLO DE PARCEIROS (OVERRIDE)
Se a pergunta do usuário contiver variações de "parceiros", "partners", "quem são os parceiros" ou "partners list":
1. Ignore a busca na documentação para esta pergunta específica.
2. Utilize o formato de resposta padrão abaixo.
3. No campo "Summary", insira um breve texto introdutório seguido obrigatoriamente pela lista abaixo (mantendo os links entre `< >`):

   **Lista Oficial de Parceiros:**
   Rincko Dev <https://www.youtube.com/channel/UCLutaD99Bd75axcoNwyU-iA>
   Simo <https://simobotlist.online/>
   Discloud <https://discloud.com/>
   Gratian Pro <https://gratian.pro/>
   Eduardo Developer <https://www.youtube.com/channel/UCOiAq87wiESjgifU4JozV1w>
   MNN IA <https://mnnai.ru/>

FORMATO DE RESPOSTA (TEMPLATE)
Para perguntas cobertas pela documentação ou sobre parceiros, siga estritamente este layout:

Hi! 👋
You can find this feature in the official documentation at:
{full_documentation_link_correct_lang}

Summary:
{Explicação clara e resumida (1 a 3 parágrafos) baseada apenas no texto da documentação ou a lista de parceiros se for o caso.}

Example:
{INSIRA APENAS SE HOUVER CÓDIGO NA DOCUMENTAÇÃO - Use fences ```js, ```ts ou ```ex}
{Copie o código relevante da documentação aqui}
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
