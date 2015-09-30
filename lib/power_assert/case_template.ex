defmodule PowerAssert.CaseTemplate do
  defmacro __using__(_) do
    quote do
      use PowerAssert.ExUnitCaseTemplate
      import PowerAssert.Assertion
    end
  end
end
