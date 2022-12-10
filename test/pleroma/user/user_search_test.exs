defmodule Pleroma.User.SearchTest do
  use Pleroma.DataCase

  describe "sanitise_domain/1" do
    test "should remove url-reserved characters" do
      examples = [
        ["example.com", "example.com"],
        ["no spaces", "nospaces"],
        ["no@at", "noat"],
        ["dash-is-ok", "dash-is-ok"],
        ["underscore_not_so_much", "underscorenotsomuch"],
        ["no!", "no"],
        ["no?", "no"],
        ["a$b%s^o*l(u)t'e#l<y n>o/t", "absolutelynot"]
      ]

      for [input, expected] <- examples do
        assert Pleroma.User.Search.sanitise_domain(input) == expected
      end
    end
  end
end
