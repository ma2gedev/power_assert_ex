defmodule PowerAssert do
  defmacro __using__(opts) do
    use_ex_unit = Keyword.get(opts, :use_ex_unit, false)
    if !use_ex_unit do
      quote do
        use ExUnit.Case, unquote(opts)
        import ExUnit.Assertions, except: [assert: 1, assert: 2]
        import PowerAssert.Assertion
      end
    else
      quote do
        require PowerAssert.Assertion
        defmacro power_assert(ast, msg \\ nil) do
          quote do
            PowerAssert.Assertion.assert(unquote(ast), unquote(msg))
          end
        end
      end
    end
  end
end
