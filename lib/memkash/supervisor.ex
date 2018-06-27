defmodule Memkash.Supervisor do
  use Supervisor

  @default_host "127.0.0.1"
  @default_port "11211"
  @default_auth_method :none
  @default_username ""
  @default_password ""
  @default_timeout 5000
  @default_socket_opts [:binary, {:nodelay, true}, {:active, false}, {:packet, :raw}]
  @default_pool_size 5
  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    pool_args = [
      name: {:local, Memkash.Pool},
      worker_module: Memkash.Worker,
      size: Env.get(:memkash, :pool_size, @default_pool_size),
      max_overflow: 20
    ]

    worker_args = [
      host: Env.get(:memkash, :memd_host, @default_host),
      port: Env.get(:memkash, :memd_port, @default_port),
      auth_method: Env.get(:memkash, :memd_auth_method, @default_auth_method),
      username: Env.get(:memkash, :memd_username, @default_username),
      password: Env.get(:memkash, :memd_password, @default_password),
      opts: Env.get(:memkash, :socket_opts, @default_socket_opts),
      timeout: Env.get(:memkash, :memd_timeout, @default_timeout)
    ]

    poolboy_sup = :poolboy.child_spec(Memkash.Pool.Supervisor, pool_args, worker_args)
    children = [poolboy_sup]
    supervise(children, strategy: :one_for_one)
  end
end
