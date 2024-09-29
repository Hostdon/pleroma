defmodule Pleroma.Web.XMLTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.XML

  test "parses normal XML" do
    data = File.read!("test/fixtures/xml_normal.xml")
    assert {:ok, _} = XML.parse_document(data)
  end

  test "refuses to parse any entities from XML" do
    data = File.read!("test/fixtures/xml_billion_laughs.xml")
    assert(:error == XML.parse_document(data))
  end

  test "refuses to load external entities from XML" do
    data = File.read!("test/fixtures/xml_external_entities.xml")
    assert(:error == XML.parse_document(data))
  end
end
