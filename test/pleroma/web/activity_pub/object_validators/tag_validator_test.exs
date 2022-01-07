# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.TagValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.TagValidator

  test "it validates an Edition" do
    edition = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "asin" => "",
      "authors" => ["https://bookwyrm.com/author/3"],
      "cover" => %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "name" => "Piranesi (2020, Bloomsbury Publishing)",
        "type" => "Document",
        "url" => "https://bookwyrm.com/images/covers/9fd28af7-ebb8-4df3-80c8-28488fc5349f.jpeg"
      },
      "description" => "",
      "editionRank" => 7,
      "firstPublishedDate" => "",
      "goodreadsKey" => "",
      "id" => "https://bookwyrm.com/book/10",
      "isbn10" => "163557563X",
      "isbn13" => "9781635575637",
      "languages" => ["English"],
      "librarythingKey" => "",
      "oclcNumber" => "",
      "openlibraryKey" => "OL28300471M",
      "pages" => 272,
      "physicalFormat" => "",
      "physicalFormatDetail" => "hardcover",
      "publishedDate" => "2020-09-15T00:00:00+00:00",
      "publishers" => ["Bloomsbury Publishing"],
      "series" => "",
      "seriesNumber" => "",
      "sortTitle" => "",
      "subjectPlaces" => [],
      "subjects" => [],
      "subtitle" => "",
      "title" => "Piranesi",
      "type" => "Edition",
      "work" => "https://bookwyrm.com/book/9"
    }

    assert %{valid?: true, changes: %{name: "Piranesi"}} = TagValidator.cast_and_validate(edition)
  end

  test "it should validate an author" do
    author = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "aliases" => [],
      "bio" => "snipped",
      "bnfId" => "14603397h",
      "born" => "1959-11-01T00:00:00+00:00",
      "goodreadsKey" => "",
      "id" => "https://bookwyrm.com/author/3",
      "isni" => "0000 0001 0877 1086",
      "librarythingKey" => "",
      "name" => "Susanna Clarke",
      "openlibraryKey" => "OL1387961A",
      "type" => "Author",
      "viafId" => "19931023",
      "wikipediaLink" => ""
    }

    assert %{valid?: true, changes: %{name: "Susanna Clarke"}} =
             TagValidator.cast_and_validate(author)
  end

  test "it should validate a work" do
    work = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "authors" => ["https://bookwyrm.com/author/3"],
      "cover" => %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "name" => "Piranesi",
        "type" => "Document",
        "url" => "https://bookwyrm.com/images/covers/e950ac10-feaf-4c3e-b2d3-de20d3a28329.jpeg"
      },
      "description" => "snipped",
      "editions" => [
        "https://bookwyrm.com/book/12",
        "https://bookwyrm.com/book/10",
        "https://bookwyrm.com/book/14",
        "https://bookwyrm.com/book/13",
        "https://bookwyrm.com/book/11",
        "https://bookwyrm.com/book/15"
      ],
      "firstPublishedDate" => "",
      "goodreadsKey" => "",
      "id" => "https://bookwyrm.com/book/9",
      "languages" => [],
      "lccn" => "",
      "librarythingKey" => "",
      "openlibraryKey" => "OL20893680W",
      "publishedDate" => "",
      "series" => "",
      "seriesNumber" => "",
      "sortTitle" => "",
      "subjectPlaces" => [],
      "subjects" => ["English literature"],
      "subtitle" => "",
      "title" => "Piranesi",
      "type" => "Work"
    }

    assert %{valid?: true, changes: %{name: "Piranesi"}} = TagValidator.cast_and_validate(work)
  end
end
