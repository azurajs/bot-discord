# AzuraJS Discord Bot

Bot oficial da AzuraJS para integração e automação no Discord. Este bot foi desenvolvido em Elixir e tem como objetivo facilitar a gestão da comunidade, automatizar tarefas e integrar serviços úteis para desenvolvedores.

## Funcionalidades

- Comandos personalizados para membros da AzuraJS
- Integração com APIs externas (ex: OpenAI)
- Moderação básica
- Mensagens automáticas e depoimentos
- Extensível para novas funcionalidades

## Requisitos

- [Elixir](https://elixir-lang.org/) >= 1.13
- [Erlang/OTP](https://www.erlang.org/downloads)
- Token de bot do Discord

## Instalação

1. Clone o repositório:
  ```sh
  git clone https://github.com/azurajs-org/bot-discord.git
  cd bot-discord
  ```
2. Instale as dependências:
  ```sh
  mix deps.get
  ```

## Configuração

1. Copie o arquivo `.env.example` para `.env` e preencha com seu token do Discord:
  ```sh
  cp .env.example .env
  # Edite o arquivo e insira seu token
  ```
2. Configure outros parâmetros em `config/config.exs` se necessário.

## Executando o Bot

Para rodar o bot localmente:

```sh
mix run --no-halt
```

O bot deve iniciar e conectar ao Discord. Verifique o console para logs de inicialização.

## Principais Comandos

- `!ajuda` — Lista comandos disponíveis
- `!depoimento` — Envia depoimento para a comunidade
- `!ping` — Testa se o bot está online

Outros comandos podem ser adicionados em `lib/azurajs_bot/`.

## Docker

Para rodar o bot em container:

```sh
docker build -t azurajs-bot .
docker run --env-file .env azurajs-bot
```

## Testes

Execute os testes com:

```sh
mix test
```

## Contribuição

1. Fork este repositório
2. Crie uma branch (`git checkout -b minha-feature`)
3. Faça suas alterações
4. Envie um pull request

Consulte o arquivo `CONTRIBUTING.md` para mais detalhes.

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais informações.

