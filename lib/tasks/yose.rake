# frozen_string_literal: true

namespace :yose do
  desc "CiNii Research で単発検索する (name=神田伯山 [kind=articles])"
  task :search, %i[name kind] => :environment do |_t, args|
    name = args[:name] or raise ArgumentError, "usage: bin/rails yose:search[神田伯山,articles]"
    kind = (args[:kind] || "all").to_sym
    client = Cinii::Client.new
    res = client.search(kind: kind, q: name)
    puts "#{res.kind}: #{res.total} hits"
    res.items.each do |it|
      puts "  - #{it['title']} | #{it['creator']} | #{it['date']} | #{it['url']}"
    end
  end

  desc "現役講談師名簿(2026年版・123名)を DB に読み込む (CiNii 不使用)"
  task load_kodanshi: :environment do
    results = Kodanshi.load_roster!(store: Yose::Store.new)
    created = results.count { |r| r[:status] == :created }
    exists = results.count { |r| r[:status] == :exists }
    puts "roster: #{created} created / #{exists} already exist / #{results.size} total"
  end

  desc "講談師名簿の各名で CiNii Research を検索し cinii フィールドを保存する (CINII_APPID 必須)"
  task sync_kodanshi: :environment do
    client = Cinii::Client.new
    results = Kodanshi.sync_ciinii!(client: client, store: Yose::Store.new)
    totals = results.map { |r| r[:totals] }
    puts "synced #{results.size} kodanshi (max totals: #{totals.max_by { |t| t['all'] }})"
  end

  desc "jsonb 検索する (obj='{\"type\":\"講談師\"}')"
  task :find, [:obj] => :environment do |_t, args|
    obj = JSON.parse(args[:obj] || '{"type":"講談師"}')
    Yose::Store.new.search(obj).each do |r|
      puts "#{r['uid']}  #{r['obj'].inspect}"
    end
  end

  desc "静的API(data/all_graph.json, data/zenza.json)を bin/generate_all_graph で生成する"
  task export_pages: :environment do
    system(Rails.root.join("bin/generate_all_graph").to_s, exception: true)
    puts "data/all_graph.json + data/zenza.json を更新しました"
  end
end