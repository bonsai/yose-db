#!/bin/bash
# GitHub Pages サイト(リポジトリルート) のローカルプレビュー用。
# all_graph.html / zenza.html / data/*.json を返す。puma と同じく Windows 起点で常駐させる。
set -u
cd /home/bons/yose-db || exit 1
exec python3 -m http.server 8008 --bind 0.0.0.0 >> /home/bons/yose-db/log/static.log 2>&1