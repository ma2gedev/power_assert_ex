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

defmodule MyCaseUsing do
  use PowerAssert.CaseTemplate

  using do
    quote do
      import MyCaseUsing
    end
  end

  def my_function(msg) do
    msg
  end

  setup do
    {:ok, executed: "setup func"}
  end
end

defmodule MyTestUsing do
  use MyCaseUsing, async: true

  test "using function is available" do
    assert my_function("using") == "using"
  end

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
