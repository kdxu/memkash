defmodule Memkash.Transcoder do
  @type_flag 0x0000

  def encode_value(value) do
    {:erlang.term_to_binary(value), @type_flag}
  end

  def decode_value(value, @type_flag) do
    :erlang.binary_to_term(value)
  end

  def decode_value(_value, data_type), do: {:error, {:invalid_data_type, data_type}}
end
