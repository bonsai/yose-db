# frozen_string_literal: true

require "test_helper"

class Api::V1::KodanshiControllerTest < ActionDispatch::IntegrationTest
  def setup
    @store = Yose::Store.new
    @store.search({}).each { |r| @store.free(r["uid"]) }
    Kodanshi.load_roster!(store: @store)
  end

  def teardown
    @store.search({}).each { |r| @store.free(r["uid"]) }
  end

  FakeCinii = Class.new do
    def search(kind:, q:)
      Cinii::Client::Response.new(kind: kind.to_s, total: 1, start_index: 1,
                                  items_per_page: 1, title: "t", request: "u",
                                  items: [{ "title" => q, "url" => "https://cir.nii.ac.jp/crid/1" }])
    end
  end

  def test_index_returns_kodanshi
    get api_v1_kodanshi_index_url
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 123, body["count"]
    assert_equal 123, body["kodanshi"].size
    koudan = body["kodanshi"].find { |k| k["obj"]["name"] == "神田伯山" }
    assert_equal "日本講談協会", koudan["obj"]["org"]
  end

  def test_show_returns_one
    record = @store.search({ "type" => "講談師", "name" => "神田伯山" }).first
    get api_v1_kodanshi_url(record["uid"])
    assert_response :success
    assert_equal "神田伯山", JSON.parse(response.body)["obj"]["name"]
  end

  def test_show_missing_uid_returns_404
    get api_v1_kodanshi_url("00000000-0000-0000-0000-000000000000")
    assert_response :not_found
  end

  def test_sync_ciinii_for_one_name
    Cinii::Client.stub :new, FakeCinii.new do
      post sync_api_v1_kodanshi_index_url, params: { names: ["神田伯山"] }, as: :json
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["synced"].size
    entry = @store.search({ "type" => "講談師", "name" => "神田伯山" }).first
    assert_equal 1, entry["obj"].dig("cinii", "totals", "all")
  end
end