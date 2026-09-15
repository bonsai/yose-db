#!/bin/bash
# GitHub Pages サイト(docs/) のローカルプレビュー用。puma と同じく Windows 起点で常駐させる。
set -u
cd /home/bons/yose-db/docs || exit 1
exec python3 -m http.server 8008 --bind 0.0.0.0 >> /home/bons/yose-db/log/static.log 2>&1