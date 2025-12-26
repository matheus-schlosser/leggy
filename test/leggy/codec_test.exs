defmodule Leggy.CodecTest do
  use ExUnit.Case
  alias Leggy.Codec

  test "encodes struct to JSON" do
    struct = %{
      __struct__: :Example,
      user: "r2d2",
      ttl: 2,
      valid?: true,
      requested_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    json = Codec.encode!(struct)
    assert json =~ "user"
    assert json =~ "ttl"
    assert json =~ "valid?"
    assert json =~ "requested_at"
  end

  test "decode returns map" do
    json = ~s({"user": "r2d2", "ttl": 5})
    assert {:ok, map} = Codec.decode(json)
    assert map.user == "r2d2"
    assert map.ttl == 5
  end

  test "decode returns error for invalid JSON" do
    assert {:error, _} = Codec.decode("invalid_json")
  end
end
