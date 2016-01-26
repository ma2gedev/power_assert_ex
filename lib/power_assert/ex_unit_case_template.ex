defmodule PowerAssert.ExUnitCaseTemplate do
  defmacro __using__(_) do
    ast = quote(do: (ExUnit.CaseTemplate.__using__([])))
    |> Macro.expand_once(__CALLER__)
    |> Macro.prewalk(&PowerAssert.AssertionEraser.except_assert/1)
    |> Macro.postwalk(&PowerAssert.AssertionEraser.modify_proxy_ast/1)
    |> Macro.postwalk(&PowerAssert.AssertionEraser.except_using/1)

    quote do
      unquote(ast)
      import PowerAssert.ExUnitCaseTemplate
    end
  end

  # from ExUnit.CaseTemplate
  defmacro using(var \\ quote(do: _), do: block) do
    quote location: :keep do
      defmacro __using__(unquote(var) = opts) do
        include_ex_unit = ExUnit.CaseTemplate.__proxy__(__MODULE__, opts)
        parent = Macro.postwalk(include_ex_unit, &PowerAssert.AssertionEraser.replace_ex_unit/1)
        result = unquote(block)
        {:__block__, [], [parent, result]}
      end
    end
  end
end
