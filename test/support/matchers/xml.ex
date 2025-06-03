defmodule Pleroma.Test.Matchers.XML do
  import ExUnit.Assertions

  def assert_xml_equals(xml_a, xml_b) do
    map_a = XmlToMap.naive_map(xml_a)
    map_b = XmlToMap.naive_map(xml_b)

    if map_a != map_b do
      flunk(~s|Expected XML
      #{xml_a}
      
      to equal

      #{xml_b}
    |)
    end
  end
end
