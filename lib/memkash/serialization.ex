defmodule Memkash.Serialization do
  alias Memkash.Serialization.Opcode

  defmodule Header do
    defstruct magic: 0, opcode: 0, key_length: 0, extras_length: 0, status: 0, total_body_length: 0, cas: 0
    @length 24
    def length, do: @length
  end

  def encode_request(header, key, body \\ "", extras \\ "") do
    %Header{opcode: opcode, cas: cas} = header

    opcode = Opcode.to_byte(opcode)
    key_length = byte_size(IO.iodata_to_binary(key))
    extras_length = byte_size(extras)

    total_body = <<extras::binary, IO.iodata_to_binary(key)::binary, body::binary>>
    total_body_length = byte_size(total_body)

    <<0x80::size(8), opcode::size(8), key_length::size(16), extras_length::size(8), 0::size(8), 0::size(16),
      total_body_length::size(32), 0::size(32), cas::size(64), total_body::binary>>
  end

  def decode_response_header(
        <<0x81::size(8), opcode::size(8), key_length::size(16), extras_length::size(8), _data_type::size(8),
          status::size(16), total_body_length::size(32), _opaque::size(32), cas::size(64)>>
      ) do
    {:ok,
     %Header{
       magic: 0x81,
       opcode: Opcode.to_atom(opcode),
       key_length: key_length,
       extras_length: extras_length,
       status: status_atom(status),
       total_body_length: total_body_length,
       cas: cas
     }}
  end

  def decode_response_header(_bytes), do: {:error, :invalid_header}

  def decode_response_body(header, total_body) do
    key_length = header.key_length
    extras_length = header.extras_length
    body_length = header.total_body_length - (key_length + extras_length)
    <<extras::binary-size(extras_length), key::binary-size(key_length), body::binary-size(body_length)>> = total_body
    {:ok, key, body, extras}
  end

  @status_map %{
    0x00 => :ok,
    0x01 => :key_not_found,
    0x02 => :key_exists,
    0x03 => :value_too_large,
    0x04 => :invalid_arguments,
    0x05 => :item_not_stored,
    0x06 => :incr_or_decr_on_non_numeric_value,
    0x20 => :auth_failure,
    0x21 => :auth_continue
  }
  defp status_atom(status) do
    Map.get(@status_map, status, {:error, :unknown_status})
  end
end

defmodule Memkash.Serialization.Opcode do
  @to_quiet_map %{
    get: :getq,
    getk: :getkq,
    set: :setq,
    add: :addq,
    replace: :replaceq,
    delete: :deleteq,
    increment: :incrementq,
    decrement: :decrementq,
    quit: :quitq,
    flush: :flushq,
    append: :appendq,
    prepend: :prependq
  }

  def quiet?(opcode) do
    opcode in Map.values(@to_quiet_map)
  end

  def get?(opcode) do
    opcode in [:get, :getq, :getk, :getkq]
  end

  def set?(opcode) do
    opcode in [:set, :setq]
  end

  def to_quiet(term) do
    Map.get(@to_quiet_map, term, {:error, :not_quiet})
  end

  def to_byte(:get), do: 0x00
  def to_byte(:set), do: 0x01
  def to_byte(:add), do: 0x02
  def to_byte(:replace), do: 0x03
  def to_byte(:delete), do: 0x04
  def to_byte(:increment), do: 0x05
  def to_byte(:decrement), do: 0x06
  def to_byte(:quit), do: 0x07
  def to_byte(:flush), do: 0x08
  def to_byte(:getq), do: 0x09
  def to_byte(:noop), do: 0x0A
  def to_byte(:version), do: 0x0B
  def to_byte(:getk), do: 0x0C
  def to_byte(:getkq), do: 0x0D
  def to_byte(:append), do: 0x0E
  def to_byte(:prepend), do: 0x0F
  def to_byte(:stat), do: 0x10
  def to_byte(:setq), do: 0x11
  def to_byte(:addq), do: 0x12
  def to_byte(:replaceq), do: 0x13
  def to_byte(:deleteq), do: 0x14
  def to_byte(:incrementq), do: 0x15
  def to_byte(:decrementq), do: 0x16
  def to_byte(:quitq), do: 0x17
  def to_byte(:flushq), do: 0x18
  def to_byte(:appendq), do: 0x19
  def to_byte(:prependq), do: 0x1A

  def to_byte(:sasl_list_mechanisms), do: 0x20
  def to_byte(:sasl_authenticate), do: 0x21
  def to_byte(:sasl_step), do: 0x22

  def to_atom(0x00), do: :get
  def to_atom(0x01), do: :set
  def to_atom(0x02), do: :add
  def to_atom(0x03), do: :replace
  def to_atom(0x04), do: :delete
  def to_atom(0x05), do: :increment
  def to_atom(0x06), do: :decrement
  def to_atom(0x07), do: :quit
  def to_atom(0x08), do: :flush
  def to_atom(0x09), do: :getq
  def to_atom(0x0A), do: :noop
  def to_atom(0x0B), do: :version
  def to_atom(0x0C), do: :getk
  def to_atom(0x0D), do: :getkq
  def to_atom(0x0E), do: :append
  def to_atom(0x0F), do: :prepend
  def to_atom(0x10), do: :stat
  def to_atom(0x11), do: :setq
  def to_atom(0x12), do: :addq
  def to_atom(0x13), do: :replaceq
  def to_atom(0x14), do: :deleteq
  def to_atom(0x15), do: :incrementq
  def to_atom(0x16), do: :decrementq
  def to_atom(0x17), do: :quitq
  def to_atom(0x18), do: :flushq
  def to_atom(0x19), do: :appendq
  def to_atom(0x1A), do: :prependq

  def to_atom(0x20), do: :sasl_list_mechanisms
  def to_atom(0x21), do: :sasl_authenticate
  def to_atom(0x22), do: :sasl_step
end
