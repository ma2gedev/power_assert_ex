defmodule PowerAssert.DebugTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  import PowerAssert.Debug

  test "puts_expr" do
    expect = """
    [1, 2, 3] |> Enum.take(1) |> Enum.empty?
                      |               |
                      [1]             false
    """
    assert capture_io(fn ->
      puts_expr [1,2,3] |> Enum.take(1) |> Enum.empty?
    end) == expect

    expect = """
    :hoge == :fuga
    """
    assert capture_io(fn ->
      puts_expr :hoge == :fuga
    end) == expect
  end
end
