# Power Assert

[![hex.pm version](https://img.shields.io/hexpm/v/power_assert.svg)](https://hex.pm/packages/power_assert) [![hex.pm daily downloads](https://img.shields.io/hexpm/dd/power_assert.svg)](https://hex.pm/packages/power_assert) [![hex.pm weekly downloads](https://img.shields.io/hexpm/dw/power_assert.svg)](https://hex.pm/packages/power_assert) [![hex.pm downloads](https://img.shields.io/hexpm/dt/power_assert.svg)](https://hex.pm/packages/power_assert) [![Build Status](https://github.com/ma2gedev/power_assert_ex/workflows/Elixir%20CI/badge.svg?branch=master)](https://github.com/ma2gedev/power_assert_ex/actions?query=workflow%3A%22Elixir+CI%22) [![License](https://img.shields.io/hexpm/l/power_assert.svg)](http://www.apache.org/licenses/LICENSE-2.0)

Power Assert makes test results easier to understand, without changing your ExUnit test code.

![Demo](https://github.com/ma2gedev/power_assert_ex/raw/master/head.gif)

Example test is here:

```elixir
test "Enum.at should return the element at the given index" do
  array = [1, 2, 3, 4, 5, 6]; index = 2; two = 2
  assert array |> Enum.at(index) == two
end
```

Here is the difference between ExUnit and Power Assert results:

![Difference between ExUnit and Power Assert](https://github.com/ma2gedev/power_assert_ex/raw/master/difference.png)

Enjoy :muscle: !

## Installation

Add Power Assert to your `mix.exs` dependencies:

```elixir
defp deps do
  [{:power_assert, "~> 0.2.0", only: :test}]
end
```

and fetch `$ mix deps.get`.

## Usage

Replace `use ExUnit.Case` into `use PowerAssert` in your test code:

```elixir
## before(ExUnit)
defmodule YourAwesomeTest do
  use ExUnit.Case  # <-- **HERE**
end

## after(PowerAssert)
defmodule YourAwesomeTest do
  use PowerAssert  # <-- **REPLACED**
end
```

Done! You can run `$ mix test`.

### Use with ExUnit.CaseTemplate

Insert `use PowerAssert` with `ExUnit.CaseTemplate.using/2` macro:

```elixir
## before(ExUnit.CaseTemplate)
defmodule YourAwesomeTest do
  use ExUnit.CaseTemplate
end

## after(PowerAssert)
defmodule YourAwesomeTest do
  use ExUnit.CaseTemplate

  # add the following
  using do
    quote do
      use PowerAssert
    end
  end
end
```

### protip: useful command to replace `use ExUnit.Case`

```bash
$ git grep -l 'use ExUnit\.Case' | xargs sed -i.bak -e 's/use ExUnit\.Case/use PowerAssert/g'
```

## How to use with other framework depending on ExUnit such as ExSpec

### ExSpec

Append `use PowerAssert` after `use ExSpec`:

```elixir
defmodule ExSpecBasedTest do
  use ExSpec
  use PowerAssert   # <-- append

  describe "describe" do
    it "it" do
      assert something == "hoge"
    end
  end
end
```

See also: test/ex_spec/ex_spec_test.exs


## API

Only provide `assert` macro:

```elixir
assert(expression, message \\ nil)
```

## Dependencies

- ExUnit

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

## Resources

- [Testing with Power Assert in Elixir projects](http://qiita.com/ma2ge/items/29115d0afbf97a092783)
- [Power Assert Inside in Elixir](https://speakerdeck.com/ma2gedev/power-assert-inside-in-elixir)

## Author

Takayuki Matsubara (@ma2ge on twitter)

## License

Distributed under the Apache 2 License.

Check [LICENSE](LICENSE) files for more information.

