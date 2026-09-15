# frozen_string_literal: true

require "test_helper"

class CiniiClientTest < ActiveSupport::TestCase
  JSONLD = {
    "@context" => {},
    "@id" => "https://cir.nii.ac.jp/opensearch/articles?q=test",
    "@graph" => [{
      "@id" => "https://cir.nii.ac.jp/opensearch/articles?q=test",
      "@type" => "channel",
      "title" => "CiNii Research articles - test",
      "opensearch:totalResults" => "2",
      "opensearch:startIndex" => "1",
      "opensearch:itemsPerPage" => "20",
      "items" => [
        {
          "@id" => "https://cir.nii.ac.jp/crid/1",
          "title" => [{ "@value" => "講談と講談師" }],
          "dc:creator" => [{ "name" => "神田伯山" }],
          "dc:date" => { "@value" => "2023" },
          "prism:publicationName" => [{ "@value" => "芸能研究" }],
          "rdfs:seeAlso" => { "@id" => "https://cir.nii.ac.jp/crid/1.json" }
        },
        {
          "@id" => "https://cir.nii.ac.jp/crid/2",
          "title" => "講談の歴史",
          "dc:creator" => "山田太郎",
          "dc:date" => [{ "@value" => "2020" }]
        }
      ]
    }]
  }.freeze

  class StubClient < Cinii::Client
    attr_reader :last_url

    def initialize(fixture)
      @fixture = fixture
      super(appid: "test-app-id")
    end

    def get(url)
      @last_url = url
      @fixture
    end
  end

  def test_search_parses_response
    client = StubClient.new(JSONLD)
    res = client.search(kind: :articles, q: "講談と講談師", count: 5)

    assert_equal "articles", res.kind
    assert_equal 2, res.total
    assert_equal 20, res.items_per_page
    assert_equal 2, res.items.size
    assert_equal "https://cir.nii.ac.jp/crid/1", res.items[0]["id"]
    assert_equal "講談と講談師", res.items[0]["title"]
    assert_equal "神田伯山", res.items[0]["creator"]
    assert_equal "2023", res.items[0]["date"]
    assert_equal "芸能研究", res.items[0]["publication"]
    assert_equal "https://cir.nii.ac.jp/crid/1.json", res.items[0]["url"]
    assert_equal "講談の歴史", res.items[1]["title"]
  end

  def test_search_builds_query_params
    client = StubClient.new(JSONLD)
    client.search(kind: :books, q: "神田伯山")

    qs = URI.decode_www_form(client.last_url.query)
    params = qs.to_h
    assert_equal "test-app-id", params["appid"]
    assert_equal "json", params["format"]
    assert_equal "ja", params["lang"]
    assert_equal "神田伯山", params["q"]
    assert_includes client.last_url.to_s, "opensearch/books"
  end

  def test_requires_appid
    client = Cinii::Client.new(appid: nil)
    assert_raises(Cinii::MissingAppId) { client.search(kind: :all, q: "x") }
  end

  def test_fetch_appends_appid
    client = StubClient.new(JSONLD)
    client.fetch("https://cir.nii.ac.jp/crid/1.json")
    qs = URI.decode_www_form(client.last_url.query).to_h
    assert_equal "test-app-id", qs["appid"]
  end
end