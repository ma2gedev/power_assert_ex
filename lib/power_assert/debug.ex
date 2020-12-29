defmodule PowerAssert.Debug do
  @moduledoc """
  This module provides debug utilities
  """

  @doc """
  execute code with inspected prints
  useful for debug

  iex> puts_expr(x |> Enum.at(y))
  x |> Enum.at(y)
  |         |  |
  |         3  2
  [1, 2, 3, 4]
  3
  """
  defmacro puts_expr(ast) do
    code = Macro.escape(ast)
    injected_ast = PowerAssert.Assertion.__inject_store_code__(ast, Macro.to_string(ast))

    quote do
      unquote(injected_ast)

      IO.puts(
        PowerAssert.Assertion.render_values(unquote(code), var!(values, PowerAssert.Assertion))
      )

      var!(result, PowerAssert.Assertion)
    end
  end
end
