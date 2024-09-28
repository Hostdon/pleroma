defmodule Pleroma.ISO639Test do
  use Pleroma.DataCase

  describe "ISO639 validation" do
    test "should validate a language" do
      assert Pleroma.ISO639.valid_alpha2?("en")
      assert Pleroma.ISO639.valid_alpha2?("ja")
      refute Pleroma.ISO639.valid_alpha2?("xx")
    end
  end
end
