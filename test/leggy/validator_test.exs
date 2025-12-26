defmodule Leggy.ValidatorTest do
  use ExUnit.Case
  alias Leggy.Validator

  defmodule EmailChangeMessage do
    def __leggy_fields__,
      do: [
        {:user, :string},
        {:ttl, :integer},
        {:valid?, :boolean},
        {:requested_at, :datetime}
      ]

    defstruct user: nil, ttl: nil, valid?: nil, requested_at: nil
  end

  test "returns struct for valid data" do
    data = %{
      user: "r2d2",
      ttl: 2,
      valid?: true,
      requested_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    assert {:ok, struct} = Validator.cast(EmailChangeMessage, data)
    assert struct.user == "r2d2"
    assert struct.ttl == 2
    assert struct.valid? == true
  end

  test "returns error for missing fields" do
    data = %{foo: "x"}

    assert {:error, {:missing_fields, fields}} = Validator.cast(EmailChangeMessage, data)

    assert :user in fields
    assert :ttl in fields
    assert :valid? in fields
    assert :requested_at in fields
  end

  test "returns error for invalid type" do
    data = %{
      user: "r2d2",
      ttl: "abc",
      valid?: true,
      requested_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    assert {:error, {:invalid_type, :ttl, :not_integer}} =
             Validator.cast(EmailChangeMessage, data)
  end
end
