defmodule PowerAssert.Debug do
  import PowerAssert.Assertion

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
    injected_ast = inject_store_code(ast, Macro.to_string(ast))

    quote do
      unquote(injected_ast)

      IO.puts(
        PowerAssert.Renderer.render(
          unquote(code),
          var!(position_and_values, PowerAssert.Assertion)
        )
      )

      var!(result, PowerAssert.Assertion)
    end
  end
end
