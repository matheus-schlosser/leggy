defmodule Example.Schemas.RabbitSchema do
  use Leggy.Schema

  schema "example_exchange", "example_queue" do
    field :user, :string
    field :ttl, :integer
    field :valid?, :boolean
    field :requested_at, :datetime
  end
end
