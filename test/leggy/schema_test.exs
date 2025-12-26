defmodule Leggy.SchemaTest do
  use ExUnit.Case
  require Leggy.Schema

  defmodule ExampleSchema do
    use Leggy.Schema

    schema "test_exchange", "test_queue" do
      field(:user, :string)
      field(:ttl, :integer)
      field(:valid?, :boolean)
      field(:requested_at, :datetime)
    end
  end

  test "struct is generated" do
    struct = %ExampleSchema{user: "r2d2", ttl: 1, valid?: true, requested_at: DateTime.utc_now()}
    assert struct.user == "r2d2"
    assert struct.ttl == 1
    assert struct.valid? == true
  end

  test "metadata functions return values" do
    assert ExampleSchema.__leggy_exchange__() == "test_exchange"
    assert ExampleSchema.__leggy_queue__() == "test_queue"
    assert is_list(ExampleSchema.__leggy_fields__())
  end
end
