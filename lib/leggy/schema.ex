defmodule Leggy.Schema do
  @moduledoc """
  Provides schema definition macros for message contracts in Leggy.
  """

  defmacro __using__(_opts) do
    quote do
      import Leggy.Schema, only: [schema: 3, field: 2]

      Module.register_attribute(__MODULE__, :leggy_fields, accumulate: true)

      @before_compile Leggy.Schema
    end
  end

  defmacro schema(exchange, queue, do: block) do
    quote do
      @leggy_exchange unquote(exchange)
      @leggy_queue unquote(queue)

      unquote(block)
    end
  end

  defmacro field(name, type) when is_atom(name) and is_atom(type) do
    quote do
      @leggy_fields {unquote(name), unquote(type)}
    end
  end

  defmacro __before_compile__(env) do
    fields = get_fields(env.module)

    quote do
      unquote(generate_struct(fields))
      unquote(generate_metadata_functions(fields))
    end
  end

  defp get_fields(module) do
    module
    |> Module.get_attribute(:leggy_fields)
    |> Enum.reverse()
  end

  defp generate_struct(fields) do
    key_value_struct =
      for {name, _type} <- fields do
        {name, nil}
      end

    quote do
      defstruct unquote(key_value_struct)
    end
  end

  defp generate_metadata_functions(fields) do
    quote do
      @doc false
      def __leggy_exchange__, do: @leggy_exchange

      @doc false
      def __leggy_queue__, do: @leggy_queue

      @doc false
      def __leggy_fields__, do: unquote(Macro.escape(fields))
    end
  end
end
