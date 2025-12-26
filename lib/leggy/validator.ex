defmodule Leggy.Validator do
  @moduledoc """
  Validating message structs defined by the Leggy schemas
  """

  def cast(schema_mod, data) do
    fields = schema_mod.__leggy_fields__()

    map = if is_list(data), do: Map.new(data), else: data

    with :ok <- validate_required(fields, map),
         {:ok, typed} <- validate_fields(fields, map) do
      {:ok, struct(schema_mod, typed)}
    else
      {:error, _} = err -> err
    end
  end

  defp validate_required(fields, map) do
    missing =
      fields
      |> Enum.map(&elem(&1, 0))
      |> Enum.reject(&Map.has_key?(map, &1))

    if missing == [], do: :ok, else: {:error, {:missing_fields, missing}}
  end

  defp validate_fields(fields, map) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {key, type}, {:ok, acc} ->
      value = Map.get(map, key)

      case cast_type(type, value) do
        {:ok, new_value} -> {:cont, {:ok, Map.put(acc, key, new_value)}}
        {:error, reason} -> {:halt, {:error, {:invalid_type, key, reason}}}
      end
    end)
  end

  defp cast_type(:string, value) when is_binary(value), do: {:ok, value}

  defp cast_type(:string, value) when is_integer(value) or is_boolean(value),
    do: {:ok, to_string(value)}

  defp cast_type(:string, _), do: {:error, :not_string}

  defp cast_type(:integer, value) when is_integer(value), do: {:ok, value}

  defp cast_type(:integer, value) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> {:ok, i}
      _ -> {:error, :not_integer}
    end
  end

  defp cast_type(:integer, _), do: {:error, :not_integer}

  defp cast_type(:boolean, value) when is_boolean(value), do: {:ok, value}

  defp cast_type(:boolean, value) when is_binary(value) do
    case String.downcase(value) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, :not_boolean}
    end
  end

  defp cast_type(:boolean, _), do: {:error, :not_boolean}

  defp cast_type(:datetime, %DateTime{} = datetime), do: {:ok, datetime}

  defp cast_type(:datetime, value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, :not_iso8601_datetime}
    end
  end

  defp cast_type(:datetime, _), do: {:error, :not_datetime}
end
