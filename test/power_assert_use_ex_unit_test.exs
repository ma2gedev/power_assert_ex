# when already `use ExUnit.Case`
# for instance other framework depending on ExUnit such as `ExSpec`
defmodule PowerAssertUseExUnitTest do
  use ExUnit.Case
  use PowerAssert, use_ex_unit: true

  test "expr" do
    import List
    power_assert ~w(hoge fuga) == ["hoge", "fuga"]
    x = "fuga"
    power_assert "hoge#{x}fuga" == "hogefugafuga"
    _one = "aiueo"
    two = 2
    power_assert [_one] = [two]
    power_assert match?(x, "fuga")
    keywords = [value: [value: "hoge"]]
    power_assert keywords[:value][:value] == "hoge"
    power_assert fn(x) -> x == 1 end.(1)
    power_assert __ENV__.aliases |> Kernel.==([])
    power_assert [1,2] |> first() |> Kernel.==(1)
    power_assert self() |> Kernel.==(self())
    power_assert [1,2,3] |> Enum.take(1) |> List.delete(1) |> Enum.empty?
  end

  test "raise" do
    try do
      power_assert [1,2,3] |> Enum.take(1) |> Enum.empty?
      assert false, "should not reach"
    rescue
      error ->
        msg = """
        [1, 2, 3] |> Enum.take(1) |> Enum.empty?()
                          |               |
                          [1]             false
        """

        if error.message <> "\n" != msg do
          value = false
          assert value
        end
    end
  end
end
