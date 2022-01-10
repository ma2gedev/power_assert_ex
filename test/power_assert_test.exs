defmodule PowerAssertTest do
  use PowerAssert

  test "expr" do
    import List
    assert ~w(hoge fuga) == ["hoge", "fuga"]
    x = "fuga"
    assert "hoge#{x}fuga" == "hogefugafuga"
    _one = "aiueo"
    two = 2
    assert [_one] = [two]
    assert match?(_x, "fuga")
    keywords = [value: [value: "hoge"]]
    assert keywords[:value][:value] == "hoge"
    assert fn(x) -> x == 1 end.(1)
    assert __ENV__.aliases |> Kernel.==([])
    assert [1,2] |> first() |> Kernel.==(1)
    assert self() |> Kernel.==(self())
    assert [1,2,3] |> Enum.take(1) |> List.delete(1) |> Enum.empty?
  end

  test "raise" do
    try do
      assert [1,2,3] |> Enum.take(1) |> Enum.empty?()
      ExUnit.Assertions.assert false, "should not reach"
    rescue
      error ->
        msg = """
        [1, 2, 3] |> Enum.take(1) |> Enum.empty?()
                          |               |
                          [1]             false
        """

        if error.message <> "\n" != msg do
          value = false
          ExUnit.Assertions.assert value
        end
    end
  end

  defmacrop assert_ok(arg) do
    quote do
      assert {:ok, val} = {:ok, unquote(arg)}
    end
  end

  test "assert inside macro" do
    assert_ok 42
  end
end

defmodule PowerAssertAssertionTest do
  use ExUnit.Case

  require PowerAssert.Assertion
  alias PowerAssert.Assertion

  test "rendering" do
    expect = """
    [1, 2, 3] |> Enum.take(1) |> Enum.empty?()
                      |               |
                      [1]             false
    """
    assert_helper(expect, fn () ->
      Assertion.assert [1,2,3] |> Enum.take(1) |> Enum.empty?()
    end)
  end

  test "assignment success" do
    Assertion.assert x = 1
    assert x == 1
    Assertion.assert %{ hoge: x } = %{ hoge: "hoge" }
    assert x == "hoge"
    Assertion.assert x = %{ hoge: "hoge" }
    assert x == %{ hoge: "hoge" }
  end

  test "assignment failed" do
    expect = """
    [false] = [x]
               |
               "hoge"
    """
    assert_helper(expect, fn () ->
      x = "hoge"
      Assertion.assert [false] = [x]
    end)

    expect = """
    %{fuga: _} = x
                 |
                 %{hoge: "fuga"}
    """
    assert_helper(expect, fn () ->
      x = %{ hoge: "fuga" }
      Assertion.assert %{ fuga: _ } = x
    end)

    expect = """
    "hell" = ["hello", "hoge"] |> Enum.at(0)
                                       |
                                       "hello"
    """
    assert_helper(expect, fn () ->
      Assertion.assert "hell" = ["hello", "hoge"] |> Enum.at(0)
    end)

    expect = """
    Expected truthy, got nil

    nil = [nil, "hoge"] |> Enum.at(0)
                                |
                                nil
    """
    assert_helper(expect, fn () ->
      Assertion.assert nil = [nil, "hoge"] |> Enum.at(0)
    end)
  end

  test "with message" do
    expect = """
    failed with message

    [false] |> List.first()
                    |
                    false
    """
    assert_helper(expect, fn () ->
      Assertion.assert [false] |> List.first(), "failed with message"
    end)
  end

  test "tuple expr" do
    expect = """
    {x, :hoge} == {"x", :hoge}
     |
     "hoge"
    """
    assert_helper(expect, fn () ->
      x = "hoge"
      Assertion.assert {x, :hoge} == {"x", :hoge}
    end)

    expect = """
    {x, :hoge, :fuga} == {"x", :hoge, :fuga}
     |
     "hoge"
    """
    assert_helper(expect, fn () ->
      x = "hoge"
      Assertion.assert {x, :hoge, :fuga} == {"x", :hoge, :fuga}
    end)
  end

  test "div, rem expr" do
    expect = """
    rem(x, y) != 1
    |   |  |
    1   5  2
    """
    assert_helper(expect, fn () ->
      x = 5
      y = 2
      Assertion.assert rem(x, y) != 1
    end)

    expect = """
    div(x, y) != 2
    |   |  |
    2   5  2
    """
    assert_helper(expect, fn () ->
      x = 5
      y = 2
      Assertion.assert div(x, y) != 2
    end)
  end

  test "string == string" do
    expect = """
    hoge == fuga
    |       |
    "hoge"  "fuga"

    difference:
    hoge
    fuga
    """
    assert_helper(expect, fn () ->
      hoge = "hoge"
      fuga = "fuga"
      Assertion.assert hoge == fuga
    end)
  end

  test "string == number" do
    expect = """
    hoge == piyo
    |       |
    "hoge"  4
    """
    assert_helper(expect, fn () ->
      hoge = "hoge"
      piyo = 4
      Assertion.assert hoge == piyo
    end)
  end

  test "number" do
    expect = """
    3 == piyo
         |
         4
    """
    assert_helper(expect, fn () ->
      piyo = 4
      Assertion.assert 3 == piyo
    end)
  end

  test "!= expr" do
    expect = """
    hoge != piyo
    |       |
    4       4
    """
    assert_helper(expect, fn () ->
      hoge = 4
      piyo = 4
      Assertion.assert hoge != piyo
    end)
  end

  test "array expr" do
    expect = """
    ary1 == ary2
    |       |
    |       ["hoge"]
    ["hoge", "fuga"]
    
    only in lhs: ["fuga"]
    only in rhs: []
    """
    assert_helper(expect, fn () ->
      ary1 = ["hoge", "fuga"]
      ary2 = ["hoge"]
      Assertion.assert ary1 == ary2
    end)

    expect = """
    [1, 2, 3] == [2, 3, 4]

    only in lhs: [1]
    only in rhs: [4]
    """
    assert_helper(expect, fn () ->
      Assertion.assert [1, 2, 3] == [2, 3, 4]
    end)
  end

  test "array with pipe expr" do
    expect = """
    ary1 |> Enum.count() == ary2 |> Enum.count()
    |            |          |            |
    |            2          ["hoge"]     1
    ["hoge", "fuga"]
    """
    assert_helper(expect, fn() ->
      ary1 = ["hoge", "fuga"]
      ary2 = ["hoge"]
      Assertion.assert ary1 |> Enum.count() == ary2 |> Enum.count()
    end)
  end

  test "&& expr" do
    num = :rand.uniform(3) + 13 # avoid "this check/guard will always yield the same result"
    expect = """
    5 < num && num < 13
        |      |
        #{num}     #{num}
    """
    assert_helper(expect, fn () ->
      Assertion.assert 5 < num && num < 13
    end)
  end

  test "&& expr first" do
    expect = """
    5 < num && num < 13
        |
        4
    """
    assert_helper(expect, fn () ->
      num = 4
      Assertion.assert 5 < num && num < 13
    end)
  end

  test "|| expr" do
    expect = """
    num < 5 || 13 < num
    |               |
    10              10
    """
    assert_helper(expect, fn () ->
      num = 10
      Assertion.assert num < 5 || 13 < num
    end)
  end

  test "map expr" do
    expect = expectation_by_version("1.10.0", %{
      earlier: """
               map.value()
               |   |
               |   false
               %{value: false}
               """,
      later:   """
               map.value
               |   |
               |   false
               %{value: false}
               """
    })
    assert_helper(expect, fn () ->
      map = %{value: false}
      Assertion.assert map.value
    end)

    expect = """
    map == %{value: "hoge"}
    |
    %{value: "fuga"}

    difference:
    key :value => {"fuga", "hoge"}
    """
    assert_helper(expect, fn () ->
      map = %{value: "fuga"}
      Assertion.assert map == %{value: "hoge"}
    end)
  end

  test "nested map expr" do
    expect = expectation_by_version("1.10.0", %{
      earlier: """
               map.value().value()
               |   |       |
               |   |       false
               |   %{value: false}
               %{value: %{value: false}}
               """,
      later:   """
               map.value.value
               |   |     |
               |   |     false
               |   %{value: false}
               %{value: %{value: false}}
               """
    })
    assert_helper(expect, fn () ->
      map = %{value: %{value: false}}
      Assertion.assert map.value.value
    end)
  end

  test "keywords expr" do
    expect = """
    keywords[:value]
    |       |
    |       false
    [value: false]
    """
    assert_helper(expect, fn () ->
      keywords = [value: false]
      Assertion.assert keywords[:value]
    end)

    expect = """
    keywords == [value: "hoge"]
    |
    [value: "fuga"]

    only in lhs: [value: "fuga"]
    only in rhs: [value: "hoge"]
    """
    assert_helper(expect, fn () ->
      keywords = [value: "fuga"]
      Assertion.assert keywords == [value: "hoge"]
    end)
  end

  test "| operator" do
    expect = """
    %{map | hoge: x} == %{hoge: "hoge", fuga: "fuga"}
      |           |
      |           "x"
      %{fuga: "fuga", hoge: "hoge"}

    difference:
    key :hoge => {"x", "hoge"}
    """
    assert_helper(expect, fn () ->
      x = "x"
      map = %{hoge: "hoge", fuga: "fuga"}
      Assertion.assert %{map | hoge: x} == %{hoge: "hoge", fuga: "fuga"}
    end)

    expect = """
    [h | t] == [1, 2, 3, 4]
     |   |
     1   [2, 3]
    
    only in lhs: []
    only in rhs: [4]
    """
    assert_helper(expect, fn () ->
      h = 1
      t = [2, 3]
      Assertion.assert [h|t] == [1,2,3,4]
    end)
  end

  test "nested keywords expr" do
    expect = """
    keywords[:value][:value]
    |       |       |
    |       |       false
    |       [value: false]
    [value: [value: false]]
    """
    assert_helper(expect, fn () ->
      keywords = [value: [value: false]]
      Assertion.assert keywords[:value][:value]
    end)
  end

  test "! expr" do
    expect = """
    !truth
    ||
    |true
    false
    """
    assert_helper(expect, fn () ->
      truth = true
      Assertion.assert !truth
    end)
  end

  test "only literal expr" do
    expect = """
    false
    """
    assert_helper(expect, fn () ->
      Assertion.assert false
    end)
  end

  test "func expr" do
    expect_str = """
    func.()
    |    |
    |    false
    #Function<
    """ |> String.trim
    expect = ~r/#{Regex.escape(expect_str)}/
    assert_helper(expect, fn () ->
      func = fn () -> false end
      Assertion.assert func.()
    end)
  end

  test "func with an one argument expr" do
    expect = """
    func.(value)
    |    ||
    |    |false
    |    false
    #Function<
    """ |> String.trim
    expect = ~r/#{Regex.escape(expect)}/
    assert_helper(expect, fn () ->
      value = false
      func = fn (v) -> v end
      Assertion.assert func.(value)
    end)
  end

  test "func with arguments expr" do
    expect = """
    func.(value1, value2)
    |    ||       |
    |    |"hoge"  "fuga"
    |    false
    #Function<
    """ |> String.trim
    expect = ~r/#{Regex.escape(expect)}/
    assert_helper(expect, fn () ->
      value1 = "hoge"
      value2 = "fuga"
      func = fn (v1, v2) -> v1 == v2 end
      Assertion.assert func.(value1, value2)
    end)
  end

  test "compare funcs expr" do
    expect1 = """
    sum.(one, two) == sum.(three, one)
    |   ||    |       |   ||      |
    |   ||    |       |   |3      1
    |   ||    |       |   4
    |   |1    2       #Function<
    """ |> String.trim
    expect2 = """
    >
    |   3
    #Function<
    """ |> String.trim
    expect = ~r/#{Regex.escape(expect1)}.*#{Regex.escape(expect2)}/
    assert_helper(expect, fn () ->
      sum = fn (x, y) -> x + y end
      one = 1
      two = 2
      three = 3
      Assertion.assert sum.(one, two) == sum.(three, one)
    end)
  end

  test "* expr" do
    expect = """
    one * two * three == 7
    |   | |   | |
    1   2 2   6 3
    """
    assert_helper(expect, fn () ->
      one = 1
      two = 2
      three = 3
      Assertion.assert one * two * three == 7
    end)
  end

  test "imported function expr" do
    expect = """
    first([false, 2, 3])
    |
    false
    """
    assert_helper(expect, fn () ->
      import List
      Assertion.assert first([false,2,3])
    end)
  end

  test "imported function with pipe expr" do
    expect = """
    [false, 2] |> first()
                  |
                  false
    """
    assert_helper(expect, fn () ->
      import List
      Assertion.assert [false, 2] |> first()
    end)
  end

  test "imported function without parentheses with pipe expr" do
    expect = """
    [false, 2] |> first
                  |
                  false
    """
    assert_helper(expect, fn () ->
      import List
      Assertion.assert [false, 2] |> first
    end)
  end

  test "operators expr" do
    expect = """
    x > y
    |   |
    1   2
    """
    assert_helper(expect, fn () ->
      x = 1
      y = 2
      Assertion.assert x > y
    end)

    expect = """
    x < y
    |   |
    2   1
    """
    assert_helper(expect, fn () ->
      x = 2
      y = 1
      Assertion.assert x < y
    end)

    expect = """
    x >= y
    |    |
    1    2
    """
    assert_helper(expect, fn () ->
      x = 1
      y = 2
      Assertion.assert x >= y
    end)

    expect = """
    x <= y
    |    |
    2    1
    """
    assert_helper(expect, fn () ->
      x = 2
      y = 1
      Assertion.assert x <= y
    end)

    expect = """
    x == y
    |    |
    2    1
    """
    assert_helper(expect, fn () ->
      x = 2
      y = 1
      Assertion.assert x == y
    end)

    expect = """
    x != x
    |    |
    2    2
    """
    assert_helper(expect, fn () ->
      x = 2
      Assertion.assert x != x
    end)

    expect = """
    x || y
    |    |
    |    false
    false
    """
    assert_helper(expect, fn () ->
      x = false
      y = false
      Assertion.assert x || y
    end)

    expect = """
    x && y
    |    |
    true false
    """
    assert_helper(expect, fn () ->
      # avoid "this check/guard will always yield the same result"
      x = !!:rand.uniform(1)
      y = !:rand.uniform(1)
      Assertion.assert x && y
    end)

    expect = """
    x <> y == "hoge"
    |    |
    "fu" "ga"

    difference:
    fuga
    hoge
    """
    assert_helper(expect, fn () ->
      x = "fu"
      y = "ga"
      Assertion.assert x <> y == "hoge"
    end)

    expect = """
    x === y
    |     |
    1     1.0
    """
    assert_helper(expect, fn () ->
      x = 1
      y = 1.0
      Assertion.assert x === y
    end)

    expect = """
    x !== y
    |     |
    1     1
    """
    assert_helper(expect, fn () ->
      x = 1
      y = 1
      Assertion.assert x !== y
    end)

    expect = """
    x and y
    |     |
    true  false
    """
    assert_helper(expect, fn () ->
      x = true
      y = false
      Assertion.assert x and y
    end)

    expect = """
    x or y
    |    |
    |    false
    false
    """
    assert_helper(expect, fn () ->
      x = false
      y = false
      Assertion.assert x or y
    end)

    expect = """
    x =~ y
    |    |
    |    ~r/e/
    "abcd"
    """
    assert_helper(expect, fn () ->
      x = "abcd"
      y = ~r/e/
      Assertion.assert x =~ y
    end)

  end

  test "arithmetic ops expr" do
    expect = """
    x * y == a + b
    | | |    | | |
    2 6 3    2 5 3
    """
    assert_helper(expect, fn () ->
      x = 2
      y = 3
      a = 2
      b = 3
      Assertion.assert x * y == a + b
    end)

    expect = """
    x / y == a - b
    | | |    | | |
    | | 2    6 4 2
    6 3.0
    """
    assert_helper(expect, fn () ->
      x = 6
      y = 2
      a = 6
      b = 2
      Assertion.assert x / y == a - b
    end)

    expect = """
    x ++ y == a -- b
    | |  |    | |  |
    | |  |    | |  [1]
    | |  |    | [2, 3]
    | |  [4]  [1, 2, 3]
    | [1, 2, 3, 4]
    [1, 2, 3]

    only in lhs: [1, 4]
    only in rhs: []
    """
    assert_helper(expect, fn () ->
      x = [1, 2, 3]
      y = [4]
      a = [1, 2, 3]
      b = [1]
      Assertion.assert x ++ y == a -- b
    end)
  end

  test "unary ops expr" do
    expect = """
    -x == +y
    ||    ||
    ||    |-1
    |-1   -1
    1
    """
    assert_helper(expect, fn () ->
      x = -1
      y = -1
      Assertion.assert -x == +y
    end)

    expect = expectation_by_version("1.13.0", %{
      earlier: """
               not(x)
               |   |
               |   true
               false
               """,
      later:   """
               not x
               |   |
               |   true
               false
               """
    })
    assert_helper(expect, fn () ->
      x = true
      Assertion.assert not x
    end)

    expect = """
    !x
    ||
    |true
    false
    """
    assert_helper(expect, fn () ->
      x = true
      Assertion.assert !x
    end)
  end

  defmodule TestStruct do
    defstruct value: "hoge"
  end

  test "struct expr" do
    expect = """
    x == %TestStruct{value: "fuga"}
    |
    %PowerAssertAssertionTest.TestStruct{value: "ho"}

    difference:
    key :value => {"ho", "fuga"}
    """
    assert_helper(expect, fn () ->
      x = %TestStruct{value: "ho"}
      Assertion.assert x == %TestStruct{value: "fuga"}
    end)
  end

  test "block expr" do
    expect = """
    true == (x == y)
             |    |
             true false
    """
    assert_helper(expect, fn () ->
      x = true; y = false
      Assertion.assert true == (x == y)
    end)
  end

  @test_module_attr [1, 2, 3]
  test "module attribute expr" do
    expect = """
    @test_module_attr |> Enum.at(2) == x
    |                         |        |
    [1, 2, 3]                 3        5
    """
    assert_helper(expect, fn () ->
      x = 5
      Assertion.assert @test_module_attr |> Enum.at(2) == x
    end)
  end

  test "fn expr not supported" do
    expect = """
    (fn x -> x == 1 end).(y)
                         ||
                         |2
                         false
    """
    assert_helper(expect, fn () ->
      y = 2
      Assertion.assert fn(x) -> x == 1 end.(y)
    end)

    expect = """
    Enum.map(array, fn x -> x == 1 end) |> List.first()
         |   |                                  |
         |   [2, 3]                             false
         [false, false]
    """
    assert_helper(expect, fn () ->
      array = [2, 3]
      Assertion.assert Enum.map(array, fn(x) -> x == 1 end) |> List.first()
    end)

    # partials
    expect = """
    Enum.map(array, &(&1 == 1)) |> List.first()
         |   |                          |
         |   [2, 3]                     false
         [false, false]
    """
    assert_helper(expect, fn () ->
      array = [2, 3]
      Assertion.assert Enum.map(array, &(&1 == 1)) |> List.first()
    end)
  end

  test "= expr not supported" do
    expect = """
    List.first(_x = array)
         |
         false
    """
    assert_helper(expect, fn () ->
      array = [false, true]
      Assertion.assert List.first(_x = array)
    end)
  end

  test "string interpolation not supported" do
    expect = """
    "hoge" == "f\#{x}a"
              |
              "fuga"

    difference:
    hoge
    fuga
    """
    assert_helper(expect, fn () ->
      x = "ug"
      Assertion.assert "hoge" == "f#{x}a"
    end)
  end

  test ":: expr not supported" do
    expect = """
    "hoge" == <<"f", Kernel.to_string(x)::binary, "a">>
              |
              "fuga"

    difference:
    hoge
    fuga
    """
    assert_helper(expect, fn () ->
      x = "ug"
      Assertion.assert "hoge" == <<"f", Kernel.to_string(x)::binary, "a">>
    end)
  end

  test "sigil expr not supported" do
    expect = expectation_by_version("1.10.0", %{
      earlier: """
               ~w"hoge fuga \#{x}" == y
                                     |
                                     ["hoge", "fuga"]

               only in lhs: ["nya"]
               only in rhs: []
               """,
      later:   """
               ~w(hoge fuga \#{x}) == y
                                     |
                                     ["hoge", "fuga"]

               only in lhs: ["nya"]
               only in rhs: []
               """
    })
    assert_helper(expect, fn () ->
      x = "nya"
      y = ["hoge", "fuga"]
      Assertion.assert ~w(hoge fuga #{x}) == y
    end)
  end

  @opts [context: Elixir]
  test "quote expr not supported" do
    expect = expectation_by_version("1.13.0", %{
      earlier: """
               quote(@opts) do
                 :hoge
               end == :fuga
               |
               :hoge
               """,
      later:   """
               quote @opts do
                 :hoge
               end == :fuga
               |
               :hoge
               """
    })
    assert_helper(expect, fn () ->
      Assertion.assert quote(@opts, do: :hoge) == :fuga
    end)

    expect = expectation_by_version("1.8.0", %{
      earlier: """
               quote() do
                 unquote(x)
               end == :fuga
               |
               :hoge
               """,
      later:   """
               quote do
                 unquote(x)
               end == :fuga
               |
               :hoge
               """
    })
    assert_helper(expect, fn () ->
      x = :hoge
      Assertion.assert quote(do: unquote(x)) == :fuga
    end)
  end

  test "get_and_update_in/2, put_in/2 and update_in/2 expr are not supported" do
    expect = """
    put_in(users["john"][:age], 28) == %{"john" => %{age: 27}}
    |
    %{"john" => %{age: 28}}

    difference:
    key "john" => {%{age: 28}, %{age: 27}}
    """
    assert_helper(expect, fn () ->
      users = %{"john" => %{age: 27}}
      Assertion.assert put_in(users["john"][:age], 28) == %{"john" => %{age: 27}}
    end)

    expect = """
    update_in(users["john"][:age], &(&1 + 1)) == %{"john" => %{age: 27}}
    |
    %{"john" => %{age: 28}}

    difference:
    key "john" => {%{age: 28}, %{age: 27}}
    """
    assert_helper(expect, fn () ->
      users = %{"john" => %{age: 27}}
      Assertion.assert update_in(users["john"][:age], &(&1 + 1)) == %{"john" => %{age: 27}}
    end)

    expect = expectation_by_version("1.13.0", %{
      earlier: """
               get_and_update_in(users["john"].age(), &({&1, &1 + 1})) == {27, %{"john" => %{age: 27}}}
               |
               {27, %{"john" => %{age: 28}}}
               """,
      later:   """
               get_and_update_in(users["john"].age(), &{&1, &1 + 1}) == {27, %{"john" => %{age: 27}}}
               |
               {27, %{"john" => %{age: 28}}}
               """
    })
    assert_helper(expect, fn () ->
      users = %{"john" => %{age: 27}}
      Assertion.assert get_and_update_in(users["john"].age(), &{&1, &1 + 1}) == {27, %{"john" => %{age: 27}}}
    end)
  end

  test "for expr not supported" do
    expect = expectation_by_version("1.13.0", %{
      earlier: """
               for(x <- enum) do
                 x * 2
               end == [2, 4, 6]
               |
               [2, 4, 8]
               
               only in lhs: '\\b'
               only in rhs: [6]
               """,
      later:   """
               for x <- enum do
                 x * 2
               end == [2, 4, 6]
               |
               [2, 4, 8]
               
               only in lhs: '\\b'
               only in rhs: [6]
               """
    })
    assert_helper(expect, fn () ->
      enum = [1,2,4]
      Assertion.assert for(x <- enum, do: x * 2) == [2, 4, 6]
    end)
  end

  @hello "hello"
  test ":<<>> expr includes module attribute not supported" do
    expect = """
    <<@hello, " ", "world">> == "hello world!"
    |
    "hello world"

    difference:
    hello world
    hello world!
    """
    assert_helper(expect, fn () ->
      Assertion.assert <<@hello, " ", "world">> == "hello world!"
    end)
  end

  test "case expr not supported" do
    expect = expectation_by_version("1.13.0", %{
      earlier: """
               case(x) do
                 {:ok, right} ->
                   right
                 {_left, right} ->
                   case(right) do
                     {:ok, right} ->
                       right
                   end
               end == :doing
               |
               :done
               """,
      later:   """
               case x do
                 {:ok, right} ->
                   right

                 {_left, right} ->
                   case right do
                     {:ok, right} -> right
                   end
               end == :doing
               |
               :done
               """
    })
    assert_helper(expect, fn () ->
      x = {:error, {:ok, :done}}
      Assertion.assert (case x do
        {:ok, right} ->
          right
        {_left, right} ->
          case right do
            {:ok, right}  -> right
          end
      end) == :doing
    end)
  end

  test "__VAR__ expr" do
    expect = """
    module != __MODULE__
    |         |
    |         PowerAssertAssertionTest
    PowerAssertAssertionTest
    """
    assert_helper(expect, fn () ->
      module = __ENV__.module
      Assertion.assert module != __MODULE__
    end)
  end

  test "big map" do
    expect = expectation_by_version("1.13.0", %{
      earlier: """
               big_map == %{:hoge => "value", "value" => "hoge", ["fuga"] => [], %{hoge: :hoge} => %{}, :big => "big", :middle => "middle", :small => "small"}
               |
               %{:big => "big", :hoge => "value", :moga => "moga", :small => "small", %{hoge: :hoge} => %{}, ["fuga"] => [], "value" => "hoe"}

               only in lhs: %{moga: "moga"}
               only in rhs: %{middle: "middle"}
               difference:
               key "value" => {"hoe", "hoge"}
               """,
      later:   """
               big_map == %{
                 :hoge => "value",
                 "value" => "hoge",
                 ["fuga"] => [],
                 %{hoge: :hoge} => %{},
                 big: "big",
                 middle: "middle",
                 small: "small"
               }
               |
               %{:big => "big", :hoge => "value", :moga => "moga", :small => "small", %{hoge: :hoge} => %{}, ["fuga"] => [], "value" => "hoe"}

               only in lhs: %{moga: "moga"}
               only in rhs: %{middle: "middle"}
               difference:
               key "value" => {"hoe", "hoge"}
               """
    })
    assert_helper(expect, fn () ->
      big_map = %{:hoge => "value", "value" => "hoe", ["fuga"] => [], %{hoge: :hoge} => %{}, :big => "big", :small => "small", moga: "moga"}
      Assertion.assert big_map == %{:hoge => "value", "value" => "hoge", ["fuga"] => [], %{hoge: :hoge} => %{}, :big => "big", :middle => "middle", :small => "small"}
    end)
  end

  def assert_helper(expect, func) when is_binary(expect) do
    expect = String.trim(expect)
    try do
      func.()
      assert false, "should be failed test #{expect}"
    rescue
      error ->
        assert expect == error.message
    end
  end
  def assert_helper(expect, func) do
    try do
      func.()
      assert false, "should be failed test #{expect}"
    rescue
      error ->
        assert Regex.match?(expect, error.message)
    end
  end

  def expectation_by_version(version, %{earlier: expect_earlier, later: expect_later}) do
    case Version.compare(System.version(), version) do
      :lt -> expect_earlier
      _ -> expect_later
    end
  end

end
