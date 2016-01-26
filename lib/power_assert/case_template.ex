defmodule PowerAssert.CaseTemplate do
  defmacro __using__(_) do
    quote do
      require ExUnit.CaseTemplate
      use PowerAssert.ExUnitCaseTemplate
      import PowerAssert.Assertion
    end
  end
end
