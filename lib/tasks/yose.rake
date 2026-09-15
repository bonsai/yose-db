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

  desc "GitHub Pages 用の静的API(JSON)を docs/data/ に書き出す (全講談師グラフ + 前座)"
  task export_pages: :environment do
    docs = Rails.root.join("docs")
    data = docs.join("data")
    FileUtils.mkdir_p(data)
    store = Yose::Store.new
    all = Kodanshi::Graph.all_graph(store: store)
    zenza = Kodanshi::Graph.zenza(store: store)
    File.write(data.join("all_graph.json"), JSON.pretty_generate(all))
    File.write(data.join("zenza.json"), JSON.pretty_generate(zenza))
    puts "docs/data/all_graph.json  (#{all['meta']['member_count']} members / #{all['nodes'].size} nodes / #{all['edges'].size} edges)"
    puts "docs/data/zenza.json      (#{zenza['meta']['count']} zenza)"
  end
end