# frozen_string_literal: true

require "yaml"
require "time"

module Kodanshi
  # 現役講談師 一覧 2026年版 (wagei.deci.jp) をシードに講談師データベースを作る。
  #   - load_roster!   : 名簿(団体/階級/プロフィールURL)を jsonb に保存
  #   - sync_ciinii!   : 各講談師名で CiNii Research を検索して cinii フィールドをマージ

  SEED_FILE = Rails.root.join("db/seeds/kodanshi_2026.yml")
  SEED_META = {
    "source" => {
      "title" => "現役講談師 一覧 2026年版｜全5団体・119名の講談師",
      "url" => "https://wagei.deci.jp/wordpress/geneki-kodanshi-list-2026/"
    }
  }.freeze

  KINDS = %i[all articles books researchers].freeze
  MAX_HITS = 5

  module_function

  # シード YAML をフラットな名簿配列に変換する。
  #   [{ name:, organization:, organization_url:, rank:, url:, description: }]
  def list
    @list ||= begin
      yaml = YAML.load_file(SEED_FILE)
      out = []
      yaml.fetch("organizations").each do |org|
        org.fetch("members").each do |m|
          out << {
            name: m.fetch("name"),
            organization: org.fetch("name"),
            organization_url: org.fetch("url"),
            rank: m["rank"],
            url: m["url"]
          }
        end
      end
      yaml.fetch("free").fetch("members").each do |m|
        out << {
          name: m.fetch("name"),
          organization: "無所属",
          organization_url: nil,
          rank: nil,
          url: m["url"],
          description: m["description"]
        }
      end
      out
    end
  end

  def by_name(name)
    list.find { |m| m[:name] == name }
  end

  # 名簿を DB(jsonb) に読み込む。CiNii は不使用。既存は idempotent にスキップ。
  # returns: [{ name:, status: :created | :exists }]
  def load_roster!(store:)
    list.map do |m|
      entry = {
        "type" => "講談師",
        "name" => m[:name],
        "org" => m[:organization],
        "rank" => m[:rank]
      }
      entry["profile_url"] = m[:url] if m[:url]
      entry["description"] = m[:description] if m[:description]
      entry["source"] = SEED_META["source"]
      store.alloc!(entry)
      { name: m[:name], status: :created }
    rescue Yose::AlreadyExists
      { name: m[:name], status: :exists }
    end
  end

  # 保存済み講談師それぞれについて CiNii Research を検索し、
  # { cinii: { searched_at:, totals:, hits: } } を jsonb へマージする。
  # @param names: nil で全員、配列ならその名前に限定
  # returns: [{ name:, totals: }]
  def sync_ciinii!(client:, store:, names: nil)
    records = store.search({ "type" => "講談師" })
    records = records.select { |r| names.include?(r["obj"]["name"]) } if names

    records.map do |r|
      name = r["obj"]["name"].to_s.gsub(/\s+/, "")
      totals = {}
      hits = {}
      KINDS.each do |kind|
        res = client.search(kind: kind, q: name)
        totals[kind.to_s] = res.total
        hits[kind.to_s] = res.items.first(MAX_HITS)
      end
      store.merge(r["uid"], "cinii" => {
        "searched_at" => Time.now.utc.iso8601,
        "totals" => totals,
        "hits" => hits
      })
      { name: r["obj"]["name"], totals: totals }
    end
  end
end