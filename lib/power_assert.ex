defmodule PowerAssert do
  defmacro __using__(opts) do
    quote do
      use PowerAssert.ExUnitCase, unquote(opts)
      import PowerAssert.Assertion
    end
  end
end
