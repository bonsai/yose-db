# frozen_string_literal: true

require "digest"

module Kodanshi
  # 全講談師を「精製されたグラフ」として扱う。
  #   Kodanshi::Graph.all_graph   # 全量グラフ (ノード: 団体/講談師, エッジ: 所属)
  #   Kodanshi::Graph.zenza       # 前座のみの順位付きリスト
  # GitHub Pages の静的API (docs/data/*.json) と Rails API の両方で使う。
  module Graph
    RANKS_ORDER = %w[真打 二ツ目 前座].freeze

    module_function

    # 全講談師 + 精製グラフ。nodes は 団体/講談師、edges は belongs_to(rank 付き)。
    def all_graph(store: nil)
      store ||= Yose::Store.new
      members = list_with_cinii(store: store)
      orgs = members.group_by { |m| m[:organization] }

      nodes = orgs.map do |org_name, ms|
        {
          "id" => org_id(org_name),
          "type" => "organization",
          "name" => org_name,
          "genre" => "講談",
          "member_count" => ms.size,
          "url" => ms.first[:organization_url]
        }
      end
      nodes.concat(members.map { |m| member_node(m) })

      edges = members.map do |m|
        {
          "source" => org_id(m[:organization]),
          "target" => member_id(m),
          "type" => "belongs_to",
          "rank" => m[:rank]
        }
      end

      {
        "meta" => {
          "title" => "全講談師グラフ",
          "source" => SEED_META["source"],
          "genre" => "講談",
          "build_at" => Time.now.utc.iso8601,
          "member_count" => members.size,
          "organization_count" => orgs.size
        },
        "ranks" => RANKS_ORDER.to_h { |r| [r, members.count { |m| m[:rank] == r }] },
        "nodes" => nodes,
        "edges" => edges
      }
    end

    # 前座ランキング(注目度/話題量の暫定スコア順)。スコア = CiNii Research 合計ヒット数。
    def zenza(store: nil)
      store ||= Yose::Store.new
      members = list_with_cinii(store: store)
        .select { |m| m[:rank] == "前座" }
        .sort_by { |m| [-m[:cinii_total], m[:name]] }

      {
        "meta" => {
          "title" => "前座ランキング",
          "source" => SEED_META["source"],
          "genre" => "講談",
          "build_at" => Time.now.utc.iso8601,
          "count" => members.size,
          "basis" => "注目度/話題量(CiNii Research ヒット数の暫定スコア。今後6軸評価に置き換え)"
        },
        "members" => members.each_with_index.map do |m, i|
          {
            "rank_order" => i + 1,
            "name" => m[:name],
            "organization" => m[:organization],
            "organization_url" => m[:organization_url],
            "profile_url" => m[:url],
            "score" => m[:cinii_total],
            "cinii" => m[:cinii]
          }
        end
      }
    end

    # 名簿と保存済み cinii 話題量を突き合わせる。未同期ならスコア 0。
    def list_with_cinii(store:)
      records = store.search({ "type" => "講談師" })
      by_name = records.to_h { |r| [r["obj"]["name"], r["obj"]] }
      Kodanshi.list.map do |m|
        obj = by_name[m[:name]] || {}
        totals = obj.dig("cinii", "totals") || {}
        {
          **m,
          cinii_total: totals.fetch("all", 0).to_i,
          cinii: totals
        }
      end
    end

    def member_node(m)
      node = {
        "id" => member_id(m),
        "type" => "member",
        "name" => m[:name],
        "rank" => m[:rank],
        "organization" => m[:organization]
      }
      node["profile_url"] = m[:url] if m[:url]
      node["cinii_total"] = m[:cinii_total] if m[:cinii_total].positive?
      node
    end

    def org_id(name)
      "org-ck#{Digest::SHA1.hexdigest(name)[0, 8]}"
    end

    def member_id(m)
      "member-#{Digest::SHA1.hexdigest("#{m[:name]}:#{m[:organization]}")[0, 10]}"
    end
  end
end