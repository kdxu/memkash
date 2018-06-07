# Memkash

A simple memcached protocol client inspired by [EchoTeam/mcd](https://github.com/EchoTeam/mcd).

## Configuration

```elixir:config/config.ex
config(:memkash,
  memd_expires_in: 20000,
  memd_timeout: 1000,
  memd_host: "localhost",
  memd_port: 11121,
  ...
  )
```

```elixir:application.ex
children = [
  ...
  supervisor(Memkash.Supervisor, []),
]
```

or

```elixir
{:ok, pid} = Memkash.Supervisor.start_link()
```

## Installation

```elixir
def deps do
  [
    {:memkash, "~> 0.1.0"}
  ]
end
```

