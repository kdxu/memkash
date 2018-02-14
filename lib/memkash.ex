defmodule Memkash do
  alias Memkash.Worker
  alias Memkash.Serialization.Opcode
  @type key :: binary
  @type value :: any
  @type opts :: map

  defmodule Response do
    defstruct key: "", value: "", extras: "", status: nil, cas: 0, data_type: nil

    @type t :: %Response{
            key: binary,
            value: any,
            extras: binary,
            status: atom,
            cas: non_neg_integer,
            data_type: non_neg_integer
          }
  end

  defmodule Request do
    defstruct opcode: nil, key: "", value: "", extras: "", cas: 0
    @type t :: %Request{opcode: atom, key: binary, value: any, extras: binary, cas: non_neg_integer}
  end

  def get(key) do
    request = %Request{opcode: :get, key: key}
    [response] = multi_request([request], false)

    case response do
      %Response{status: :ok, value: value} ->
        :erlang.binary_to_term(value)
      %Response{status: :key_not_found} ->
        :not_found
      %Response{status: status} ->
        {:error, status}
    end
  end

  def set(key, value, opts \\ %{}) do
    case do_store(:set, key, value, opts) do
      %Response{status: :ok} ->
        :ok
      %Response{status: status} ->
        {:error, status}
    end
  end

  def mget(keys) do
    requests = Enum.map(keys, &%Request{opcode: :getk, key: &1})
    multi_request(requests, true)
  end

  def mset(keyvalues) do
    requests =
      keyvalues
      |> Enum.map(fn {key, value} ->
        store_request(:set, key, value, %{})
      end)

    multi_request(requests, true)
  end

  def add(key, value, opts \\ %{}), do: do_store(:add, key, value, opts)

  def replace(key, value, opts \\ %{}), do: do_store(:replace, key, value, opts)

  def append(key, value) do
    request = %Request{opcode: :append, key: key, value: value}
    [response] = multi_request([request], false)
    response
  end

  def prepend(key, value) do
    request = %Request{opcode: :prepend, key: key, value: value}
    [response] = multi_request([request], false)
    response
  end

  def delete(key) do
    request = %Request{opcode: :delete, key: key}
    [response] = multi_request([request], false)

    case response do
      %Response{status: :ok} ->
        :ok

      %Response{status: status} ->
        {:error, status}
    end
  end

  def increment(key, amount, opts \\ %{}), do: do_incr_decr(:increment, key, amount, opts)

  def decrement(key, amount, opts \\ %{}), do: do_incr_decr(:decrement, key, amount, opts)

  def flush(opts \\ %{}) do
    expires = Map.get(opts, :expires, 0)
    extras = <<expires::size(32)>>
    request = %Request{opcode: :flush, extras: extras}
    [response] = multi_request([request], false)
    response
  end

  def version() do
    request = %Request{opcode: :version}
    [response] = multi_request([request], false)
    response
  end

  defp multi_request(requests, return_stream?) do
    stream =
      Stream.resource(
        fn ->
          worker = :poolboy.checkout(Memkash.Pool)
          :ok = do_multi_request(requests, worker)
          {worker, :cont}
        end,
        fn
          {worker, :cont} = acc ->
            receive do
              {:response, {:ok, header, key, value, extras}} ->
                if extras != "" && Opcode.get?(header.opcode) do
                  <<type_flag::size(32)>> = extras

                  case Memkash.Transcoder.decode_value(value, type_flag) do
                    {:error, _error} ->
                      %Response{
                        status: :transcode_error,
                        cas: header.cas,
                        key: key,
                        value: "Transcode error",
                        extras: extras
                      }

                    value ->
                      %Response{
                        status: header.status,
                        cas: header.cas,
                        key: key,
                        value: value,
                        extras: extras,
                        data_type: type_flag
                      }
                  end
                end

                if Opcode.quiet?(header.opcode) do
                  {[%Response{status: header.status, cas: header.cas, key: key, value: value, extras: extras}], acc}
                else
                  {[%Response{status: header.status, cas: header.cas, key: key, value: value, extras: extras}],
                   {worker, :halt}}
                end

              {:response, {:error, reason}} ->
                if reason == :timeout do
                  :ok = Worker.close(worker)
                end

                {[%Response{status: reason, value: "#{inspect(reason)}"}], {worker, :halt}}
            end

          {_worker, :halt} = acc ->
            {:halt, acc}
        end,
        fn {worker, _} ->
          :poolboy.checkin(Memkash.Pool, worker)
        end
      )

    if return_stream? do
      stream
    else
      stream |> Enum.into([])
    end
  end

  defp do_multi_request([request], worker) do
    Worker.cast(worker, self(), request, request.opcode)
  end

  defp do_multi_request([request | requests], worker) do
    Worker.cast(worker, self(), request, Opcode.to_quiet(request.opcode))
    do_multi_request(requests, worker)
  end

  defp do_store(opcode, key, value, opts) do
    request = store_request(opcode, key, value, opts)
    [response] = multi_request([request], false)
    response
  end

  defp store_request(opcode, key, value, opts) do
    expires = Map.get(opts, :expires, 0)
    cas = Map.get(opts, :cas, 0)

    {value, flags} = Memkash.Transcoder.encode_value(value)
    extras = <<flags::size(32), expires::size(32)>>

    %Request{opcode: opcode, key: key, value: value, extras: extras, cas: cas}
  end

  defp do_incr_decr(opcode, key, amount, opts) do
    initial_value = Map.get(opts, :initial_value, 0)
    expires = Map.get(opts, :expires, 0)

    extras = <<amount::size(64), initial_value::size(64), expires::size(32)>>

    request = %Request{opcode: opcode, key: key, extras: extras}
    [response] = multi_request([request], false)

    if response.status == :ok do
      <<value::unsigned-integer-size(64)>> = response.value
      %{response | value: value}
    else
      response
    end
  end
end
