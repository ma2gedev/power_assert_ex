defmodule ShouldTest do
  use ShouldI
  use PowerAssert

  should "inside should" do
    assert 1 + 2 == 3
  end

  should "use power assert inside should" do
    try do
      assert [1,2,3] |> Enum.take(1) |> Enum.empty?
    rescue
      error ->
        msg = """
        [1, 2, 3] |> Enum.take(1) |> Enum.empty?
                          |               |
                          [1]             false
        """
        ExUnit.Assertions.assert error.message <> "\n" == msg
    end
  end

  having "use power assert inside having" do
    setup context do
      Map.put context, :arr, [1,2,3]
    end
    should "use power assert", context do
      try do
        array = context.arr
        assert array |> Enum.take(1) |> Enum.empty?
      rescue
        error ->
          msg = """
          array |> Enum.take(1) |> Enum.empty?
          |             |               |
          [1, 2, 3]     [1]             false
          """
          ExUnit.Assertions.assert error.message <> "\n" == msg
      end
    end
  end
end
