defmodule MyCase do
  use PowerAssert.CaseTemplate

  setup do
    {:ok, executed: "setup func"}
  end
end

defmodule MyTest do
  use MyCase, async: true

  test "executed setup function", context do
    assert context[:executed] == "setup func"
  end

  test "raise", context do
    assert context[:executed] == "setup func"
    try do
      assert [1,2,3] |> Enum.take(1) |> Enum.empty?
    rescue
      error ->
        msg = """
        [1, 2, 3] |> Enum.take(1) |> Enum.empty?()
                          |               |
                          |               false
                          [1]
        """
        ExUnit.Assertions.assert error.message <> "\n" == msg
    end
  end
end
