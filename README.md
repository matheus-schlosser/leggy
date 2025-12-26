# Leggy

Leggy é uma biblioteca para integração com RabbitMQ baseada em contratos de schema, validação e pooling de canais, projetada para facilitar a publicação e o consumo de mensagens.

## Instalação

Adicione ao `mix.exs`:

```elixir
def deps do
  [
    {:leggy, git: "https://github.com/matheus-schlosser/leggy", branch: "main"}
    {:amqp, "~> 4.0"},
    {:jason, "~> 1.4"}
  ]
end
```

## Exemplo de uso

```elixir
defmodule MyApp.RabbitRepo do
  use Leggy, host: "localhost", username: "guest", password: "guest", pool_size: 4
end

defmodule MyApp.Schemas.EmailChangeMessage do
  use Leggy.Schema

  schema "exchange_name", "queue_name" do
    field :user, :string
    field :ttl, :integer
    field :valid?, :boolean
    field :requested_at, :datetime
  end
end
```

O parâmetro `pool_size` define quantos canais AMQP simultâneos o Leggy irá manter abertos para o Repo. Cada canal permite uma operação de publicação ou consumo independente, aumentando a performance em cenários de alta concorrência. 

#### Se desejar iniciar manualmente o repo (sem alterar o application)
```elixir
{:ok, _pid} = Supervisor.start_link([YourApp.RabbitRepo], strategy: :one_for_one)
```

### Preparar exchange e fila

```elixir
MyApp.RabbitRepo.prepare(MyApp.Schemas.EmailChangeMessage)
```

### Publicar uma mensagem

```elixir
{:ok, msg} =
  MyApp.RabbitRepo.cast(MyApp.Schemas.EmailChangeMessage, %{
    user: "r2d2",
    ttl: 5,
    valid?: true,
    requested_at: DateTime.utc_now()
  })

MyApp.RabbitRepo.publish(msg)
```

### Consumir uma mensagem

```elixir
MyApp.RabbitRepo.get(MyApp.Schemas.EmailChangeMessage)
```

## Estrutura interna

- **Schema (`Leggy.Schema`)**: Fornece macros para definir contratos de mensagens (campos, tipos, nomes de exchange/queue). Garante que toda mensagem publicada ou consumida siga um formato validado e tipado.

- **Channel Pool (`Leggy.ChannelPool`)**: Gerencia um pool de canais AMQP, permitindo múltiplas operações concorrentes.Responsável por checkout/checkin de canais e reconexão automática em caso de falha.

- **Consumer (`Leggy.Consumer` e `Leggy.ConsumerTask`)**: Permite criar consumidores concorrentes e crash-only, que processam mensagens de filas específicas. O `ConsumerTask` executa o loop de consumo, validação, entrega ao handler e rejeição (nack) em caso de erro.

- **Validação (`Leggy.Validator`)**: Realiza o cast e validação de tipos dos campos das mensagens.

- **Serialização (`Leggy.Codec`)**: Responsável por serializar structs para JSON e desserializar JSON para mapas/structs.

- **API principal (`Leggy`)**: Expõe as funções de alto nível para preparar filas, publicar, consumir, validar e manipular canais, além de orquestrar a integração entre os módulos.


## Desenvolvimento

Execute o RabbitMQ localmente:

```bash
docker run -d --rm --name rabbit -p 5672:5672 rabbitmq:3-management
```

Rode os testes:

```bash
mix test
```