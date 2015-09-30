defmodule PowerAssert.ExUnitCaseTemplate do
  defmacro __using__(opts) do
    require ExUnit.CaseTemplate
    ast = quote(do: (ExUnit.CaseTemplate.__using__(unquote(opts))))
    |> Macro.expand_once(__ENV__)
    |> Macro.prewalk(&PowerAssert.AssertionEraser.except_assert/1)
    |> Macro.postwalk(&PowerAssert.AssertionEraser.modify_proxy_ast/1)

    quote do
      require ExUnit.CaseTemplate
      unquote(ast)
    end
  end
end
