# SingleFlight

Deduplicate concurrent function calls by key. Inspired by Go's
[`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) package.

When multiple processes call `SingleFlight.flight/3` with the same key
concurrently, only the first call executes the function. All other callers
block and receive the same result when the function completes.

This is useful for collapsing thundering-herd cache misses, deduplicating
expensive API calls, or any scenario where concurrent identical work is
wasteful.

## Installation

Add `single_flight` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:single_flight, "~> 0.1.0"}
  ]
end
```

## Usage

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

### Forgetting a key

If you need to invalidate a key (e.g., after a write), call `forget/2`:

```elixir
:ok = SingleFlight.forget(MyApp.Flights, "user:#{id}")
```

Existing in-flight waiters still receive the original result. Only new
callers after `forget/2` trigger a fresh execution.

### Error handling

If the function raises, throws, or exits, all waiting callers receive an
`{:error, reason}` tuple:

```elixir
{:error, {%RuntimeError{message: "boom"}, _stacktrace}} =
  SingleFlight.flight(MyApp.Flights, "bad", fn -> raise "boom" end)
```

## License

MIT — see [LICENSE](LICENSE).
