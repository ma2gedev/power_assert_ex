defmodule PowerAssert.ExUnitCase do
  defmacro __using__(opts) do
    require ExUnit.Case
    ast = quote(do: (ExUnit.Case.__using__(unquote(opts))))
    |> Macro.expand_once(__ENV__)
    |> Macro.prewalk(&PowerAssert.AssertionEraser.except_assert/1)

    quote do
      require ExUnit.Case
      unquote(ast)
    end
  end
end
