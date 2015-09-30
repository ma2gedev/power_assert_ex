defmodule PowerAssert.AssertionEraser do
  def except_assert({:import, _meta, [{_, _, [:ExUnit, :Assertions]}]}) do
    quote do
      import ExUnit.Assertions, except: [assert: 1, assert: 2]
    end
  end
  def except_assert(ast) do
    ast
  end

  # for ExUnit.CaseTemplate.__proxy__
  def modify_proxy_ast({{:., _, [ExUnit.CaseTemplate, :__proxy__]}, _, _} = ast) do
    quote do
      include_ex_unit = unquote(ast)
      Macro.postwalk(include_ex_unit, &PowerAssert.AssertionEraser.replace_ex_unit/1)
    end
  end
  def modify_proxy_ast(ast) do
    ast
  end

  # replace ExUnit.Case returned by ExUnit.CaseTemplate.__proxy__ into PowerAssert
  def replace_ex_unit({:use, _, [{:__aliases__, _, [:ExUnit, :Case]}, args]}) do
    quote do
      use PowerAssert, unquote(args)
    end
  end
  def replace_ex_unit(ast) do
    ast
  end

  def except_using({:import, _, [ExUnit.CaseTemplate]}) do
    quote do
      import ExUnit.CaseTemplate, only: :functions
    end
  end
  def except_using(ast) do
    ast
  end
end
