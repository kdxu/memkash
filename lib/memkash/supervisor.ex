defmodule Memkash.Supervisor do
  use Supervisor

  @default_host '127.0.0.1'
  @default_port 11211
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
      size: Application.get_env(:memkash, :pool_size, @default_pool_size),
      max_overflow: 20
    ]

    worker_args = [
      host: Application.get_env(:memkash, :memd_host, @default_host),
      port: Application.get_env(:memkash, :memd_port, @default_port),
      auth_method: Application.get_env(:memkash, :memd_auth_method, @default_auth_method),
      username: Application.get_env(:memkash, :memd_username, @default_username),
      password: Application.get_env(:memkash, :memd_password, @default_password),
      opts: Application.get_env(:memkash, :socket_opts, @default_socket_opts),
      timeout: @default_timeout
    ]

    poolboy_sup = :poolboy.child_spec(Memkash.Pool.Supervisor, pool_args, worker_args)
    children = [poolboy_sup]
    supervise(children, strategy: :one_for_one)
  end
end
