---
emoji: 🎍
description: 落語家の前座数(zenza_count)を協会名簿から観測し、確認できた分だけ zenza_counts.json を更新して PR を作成する
intent: 各協会の前座数と二ツ目昇進実績を定期的に観測し、名簿から確認できた値(roster)を反映するとともに、proxy 推計を再生成して Pages の静的データまで一貫して最新化する
on:
  schedule:
    - cron: "0 12 * * 1"
  workflow_dispatch:
permissions:
  contents: read
  issues: read
  pull-requests: read
tools:
  github:
    mode: gh-proxy
    toolsets: [default]
network:
  allowed:
    - rakugo-kyokai.jp
    - geikyo.com
    - kamigatarakugo.jp
    - tatekawa.info
safe-outputs:
  create-pull-request:
    allowed-files:
      - "services/rakugo/data/rakugo/**"
      - "services/rakugo/README.md"
---

# Rakugo 前座数アップデート

落語家の前座数(zenza_count)の観測→生成→提案の一連を担う agentic workflow。

## Task

1. 対象団体ごとに、公式の会員名簿・前座リストを取得する:
   - 落語協会(rakugo-kyokai.jp) — 前座一覧
   - 落語芸術協会(geikyo.com) — 前座一覧
   - 落語立川流(tatekawa.info) — 前座一覧
   - 上方落語協会(kamigatarakugo.jp) — 前座相当
   - 補助情報源として wagei.deci.jp / 東京かわら版 の名鑑ページも検索してよい
2. `services/rakugo/data/rakugo/lists/*.json` の形式(1団体1年1ファイル)に従い、
   前座の名前・階級だけを記録して更新する。名簿に載っていない名前は書かない。
   - `promotions` には、その年の二ツ目昇進者数(次の階級に上がった人数)を
     協会の告知や名鑑から確認できた範囲で記す。不明なら空のまま。
3. 更新後は `cd services/rakugo && go run ./cmd/zenza-count` を実行し、
   `data/rakugo/zenza_counts.json` を再生成する。
4. 回帰確認: `go test ./...` が通ること。
5. 前年度の名簿との差分がなければ `noop` し、理由を明示する。
   変化がある場合のみ PR を作成する。

## Evidence 原則
- 確認できた名簿から数えた値だけを `roster` とする。観測できない値は
  空のまま残し、proxy(`estimate`)はモデルに任せる。
- 確認できた値に加えなかった(省いた)項目があれば、その理由を PR 本文に付記する。

## Safe Outputs
- 変更は必ず `create-pull-request` で提案する(直接 push しない)。
- 変化がない場合・名簿が取得できない場合は `noop` で終了する。

## Success
- `zenza_counts.json` の `source: roster` 行が当日時点の協会名簿と一致する
- `go test ./...` green
- PR 本体に「取得日・元ページ URL・追加/削除した前座名」が記されている