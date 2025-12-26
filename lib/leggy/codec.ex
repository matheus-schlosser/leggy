defmodule Leggy.Codec do
  @moduledoc """
  JSON encoding/decoding with schema integration for Leggy messages.
  """

  def encode!(data) when is_map(data) do
    data
    |> Map.from_struct()
    |> Jason.encode!()
  end

  def encode!(data), do: Jason.encode!(data)

  def decode(payload) when is_binary(payload) do
    case Jason.decode(payload, keys: :atoms!) do
      {:ok, map} -> {:ok, map}
      {:error, err} -> {:error, err}
    end
  end
end
