# PowerAssert

[![hex.pm version](https://img.shields.io/hexpm/v/power_assert.svg)](https://hex.pm/packages/power_assert) [![hex.pm downloads](https://img.shields.io/hexpm/dt/power_assert.svg)](https://hex.pm/packages/power_assert) [![Build Status](https://travis-ci.org/ma2gedev/power_assert_ex.svg?branch=master)](https://travis-ci.org/ma2gedev/power_assert_ex) [![License](https://img.shields.io/hexpm/l/power_assert.svg)](http://www.apache.org/licenses/LICENSE-2.0)

PowerAssert for Elixir.

Example test is here:

```elixir
test "Enum.at should return the element at the given index" do
  array = [1, 2, 3]; index = 2; two = 2
  assert array |> Enum.at(index) == two
end
```

And the result is like the following:

```
  1) test Enum.at should return the element at the given index (PowerAssertTest)

     array |> Enum.at(index) == two
     |             |  |         |
     |             |  |         2
     |             |  2
     |             3
     [1, 2, 3]
```

Enjoy :muscle: !

## Dependencies

- ExUnit

## Installation

```
# add dependencies in mix.exs
defp deps do
  [
    {:power_assert, "~> 0.0.1"}
  ]
end

# and fetch
$ mix deps.get
```

## How to use

```elixir
# replace `use ExUnit.Case` into `use PowerAssert` in your test code

## before
defmodule YourAwesomeTest do
  use ExUnit.Case  # <-- **HERE**
end

## after
defmodule YourAwesomeTest do
  use PowerAssert  # <-- **REPLACED**
end
```

when ExUnit.CaseTemplate

```elixir
# replace `use ExUnit.CaseTemplate` into `use PowerAssert.CaseTemplate` in your test code

## before
defmodule YourAwesomeTest do
  use ExUnit.CaseTemplate       # <-- **HERE**
end

## after
defmodule YourAwesomeTest do
  use PowerAssert.CaseTemplate  # <-- **REPLACED**
end
```

useful command to replace `use ExUnit.CaseTemplate` and `use ExUnit.Case`

```bash
$ git grep -l 'use ExUnit\.CaseTemplate' | xargs sed -i.bak -e 's/use ExUnit\.CaseTemplate/use PowerAssert.CaseTemplate/g'
$ git grep -l 'use ExUnit\.Case' | xargs sed -i.bak -e 's/use ExUnit\.Case/use PowerAssert/g'
```

## API

```
assert(expression, message \\ nil)
```

## TODO

- [x] `ExUnit.CaseTemplate` with `using function`
- [ ] support `assert [one] = [two]`
  - currently rely on `ExUnit.Assertions.assert/1`
- and more we've not yet noticed

## Limitation

- NOT SUPPORTED
  - match expression ex: `assert List.first(x = [false])`
  - fn expression ex: `assert fn(x) -> x == 1 end.(2)`
  - :: expression ex: `<< x :: bitstring >>`
    - this means string interpolations also unsupported ex: `"#{x} hoge"`
  - sigil expression ex: `~w(hoge fuga)`
  - quote arguments ex: `assert quote(@opts, do: :hoge)`
  - case expression
  - get_and_update_in/2, put_in/2, update_in/2, for/1
  - <<>> expression includes attributes `<<@x, "y">>; <<x :: binary, "y">>`
  - `__MODULE__.Foo`
  - many macros maybe caught error...

## License

Distributed under the Apache 2 License.

Check [LICENSE](LICENSE) files for more information.

