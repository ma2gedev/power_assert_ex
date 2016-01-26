defmodule PowerAssert.ExUnitCase do
  defmacro __using__(opts) do
    ast = quote(do: (ExUnit.Case.__using__(unquote(opts))))
    |> Macro.expand_once(__CALLER__)
    |> Macro.prewalk(&PowerAssert.AssertionEraser.except_assert/1)

    quote do
      unquote(ast)
    end
  end
end
