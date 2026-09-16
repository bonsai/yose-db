# frozen_string_literal: true

require "test_helper"

class KodanshiTest < ActiveSupport::TestCase
  def setup
    @store = Yose::Store.new
  end

  def teardown
    @store.search({}).each { |r| @store.free(r["uid"]) }
  end

  def test_seed_list_has_123_members
    assert_equal 123, Kodanshi.list.size
    assert Kodanshi.by_name("神田伯山")
    assert_equal "日本講談協会", Kodanshi.by_name("神田伯山")[:organization]
  end

  def test_load_roster_is_idempotent
    created = Kodanshi.load_roster!(store: @store)
    assert_equal 123, created.count { |r| r[:status] == :created }

    again = Kodanshi.load_roster!(store: @store)
    assert_equal 123, again.count { |r| r[:status] == :exists }

    records = @store.search({ "type" => "講談師" })
    assert_equal 123, records.size
    assert_match(/講談師/, records.first["obj"]["type"])
    assert_equal "神田伯山", @store.search({ "type" => "講談師", "name" => "神田伯山" }).first["obj"]["name"]
  end

  def test_sync_ciinii_merges_totals
    Kodanshi.load_roster!(store: @store)

    fake = Object.new
    def fake.search(kind:, q:)
      Cinii::Client::Response.new(kind: kind.to_s, total: q == "神田伯山" ? 7 : 0,
                                  start_index: 1, items_per_page: 5, title: "t",
                                  request: "u", items: [])
    end

    results = Kodanshi.sync_ciinii!(client: fake, store: @store, names: ["神田伯山"])
    assert_equal 1, results.size
    assert_equal 7, results.first[:totals]["all"]

    entry = @store.search({ "type" => "講談師", "name" => "神田伯山" }).first
    assert_equal 7, entry["obj"].dig("cinii", "totals", "all")
    assert entry["obj"].dig("cinii", "searched_at")
  end
end