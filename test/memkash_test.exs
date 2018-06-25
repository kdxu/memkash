defmodule MemkashTest do
  use ExUnit.Case

  setup do
    {:ok, _pid} = Memkash.Supervisor.start_link()
    :ok
  end

  test "set no value" do
    Memkash.flush()
    key = ["hoge", "fuga"]
    :not_found = Memkash.get(key)
  end

  test "set/get" do
    Memkash.flush()
    key = "hoge"
    :ok = Memkash.set(key, "fuga")
    "fuga" = Memkash.get(key)
  end

  test "set/get list" do
    Memkash.flush()
    key = ["hoge", ["fuga", "piyo"]]
    value = ["nyan", "abcdef"]
    :ok = Memkash.set(key, value)
    ["nyan", "abcdef"] = Memkash.get(key)
  end

  test "expire value" do
    Memkash.flush()
    key = ["hoge", "fuga"]
    value = "nyan"
    :ok = Memkash.set(key, value, %{expires: 1})
    "nyan" = Memkash.get(key)
    :timer.sleep(2000)
    :not_found = Memkash.get(key)
  end
end
