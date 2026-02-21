# SingleFlight

[![CI](https://github.com/yoavgeva/single_flight/actions/workflows/ci.yml/badge.svg)](https://github.com/yoavgeva/single_flight/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/single_flight.svg)](https://hex.pm/packages/single_flight)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/single_flight)

Deduplicate concurrent function calls by key. Inspired by Go's
[`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) package.

When multiple processes call `SingleFlight.flight/3` with the same key
concurrently, only the first call executes the function. All other callers
block and receive the same result when the function completes.

## Why?

Imagine 100 requests hit your app at the same time, all needing user `123`
which isn't in cache yet. Without SingleFlight, you get 100 identical database
queries. With SingleFlight, you get 1 query and 99 processes waiting for the
result — for free on the BEAM (each waiting process costs ~2KB, zero CPU).

Common use cases:

- **Cache stampede / thundering herd** — collapse concurrent cache misses into a single fetch
- **Expensive API calls** — deduplicate identical outbound HTTP requests
- **Heavy computations** — compute once, share with all waiting callers

## Installation

Add `single_flight` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:single_flight, "~> 0.1.0"}
  ]
end
```

## Quick start

Add `SingleFlight` to your supervision tree:

```elixir
children = [
  {SingleFlight, name: MyApp.Flights}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Then use it to deduplicate concurrent calls:

```elixir
{:ok, user} = SingleFlight.flight(MyApp.Flights, "user:#{id}", fn ->
  Repo.get!(User, id)
end)
```

## Real-world examples

### Cache-aside with deduplication

```elixir
def get_user(id) do
  case Cachex.get(:cache, "user:#{id}") do
    {:ok, nil} ->
      # Even if 100 processes hit this branch at once,
      # only one will actually query the database
      {:ok, user} = SingleFlight.flight(MyApp.Flights, "user:#{id}", fn ->
        Repo.get!(User, id)
      end)

      Cachex.put(:cache, "user:#{id}", user)
      user

    {:ok, user} ->
      user
  end
end
```

### Deduplicating external API calls

```elixir
def fetch_exchange_rate(currency) do
  SingleFlight.flight(MyApp.Flights, "rate:#{currency}", fn ->
    {:ok, %{body: body}} = Req.get("https://api.example.com/rates/#{currency}")
    body["rate"]
  end)
end
```

### With timeout

```elixir
case SingleFlight.flight(MyApp.Flights, "slow-query", fn ->
  Repo.all(expensive_query())
end, 5_000) do
  {:ok, results} -> results
  {:error, reason} -> handle_error(reason)
end
```

Note: if the caller times out, the in-flight function continues executing
and will still deliver results to other waiting callers.

## Forgetting a key

If you need to invalidate a key (e.g., after a write), call `forget/2`:

```elixir
def update_user(id, attrs) do
  user = Repo.update!(changeset)
  :ok = SingleFlight.forget(MyApp.Flights, "user:#{id}")
  user
end
```

Existing in-flight waiters still receive the original result. Only new
callers after `forget/2` trigger a fresh execution.

## Error handling

If the function raises, throws, or exits, all waiting callers receive an
`{:error, reason}` tuple:

```elixir
# raise
{:error, {%RuntimeError{message: "boom"}, _stacktrace}} =
  SingleFlight.flight(server, "bad", fn -> raise "boom" end)

# exit
{:error, {:exit, :reason}} =
  SingleFlight.flight(server, "bad", fn -> exit(:reason) end)

# throw
{:error, {:throw, :value}} =
  SingleFlight.flight(server, "bad", fn -> throw(:value) end)
```

The server remains fully functional after errors — only the specific key's
flight is affected.

## How it works

```
Process A ──flight("user:123", fn)──► GenServer
                                        │
                                   key not found
                                        │
                                   spawn Task ─── fn.() ───┐
                                        │                   │
Process B ──flight("user:123", fn)──► GenServer             │
                                        │                   │
                                   key found!               │
                                   append to waiters        │
                                        │                   │
Process C ──flight("user:123", fn)──► GenServer             │
                                        │                   │
                                   key found!               │
                                   append to waiters        │
                                        │                   │
                                        ◄───── result ──────┘
                                        │
                                   reply to A, B, C
                                   with {:ok, result}
```

## License

MIT — see [LICENSE](LICENSE).
