#!/bin/bash
# yose-db dev server (persistent). Launched from Windows via:
#   Start-Process wsl.exe -ArgumentList '-d','Ubuntu','-e','bash','/home/bons/yose-db/scripts/dev_server.sh' -WindowStyle Hidden
set -u
cd /home/bons/yose-db || exit 1
export PATH="$HOME/.local/share/gem/ruby/3.3.0/bin:$PATH"
exec bin/rails server -b 0.0.0.0 -p 3001 >> log/puma.log 2>&1