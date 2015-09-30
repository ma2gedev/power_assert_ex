defmodule PowerAssert.CaseTemplate do
  defmacro __using__(opts) do
    quote do
      use PowerAssert.ExUnitCaseTemplate, unquote(opts)
      import PowerAssert.Assertion
    end
  end
end
