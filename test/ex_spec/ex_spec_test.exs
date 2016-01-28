defmodule ExSpecTest do
  use ExSpec
  use PowerAssert

  describe "in describe" do
    context "in context" do
      it "success" do
        assert 1 + 2 == 3
      end
    end

    context "power assert error message" do
      it "descriptive message" do
        try do
          assert [1,2,3] |> Enum.take(1) |> Enum.empty?
        rescue
          error ->
            msg = """
            [1, 2, 3] |> Enum.take(1) |> Enum.empty?()
                              |               |
                              [1]             false
            """
            ExUnit.Assertions.assert error.message <> "\n" == msg
        end
      end
    end
  end
end
