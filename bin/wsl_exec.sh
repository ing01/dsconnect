#!/usr/bin/env bash
export PATH="/home/ingri/.rbenv/shims:/home/ingri/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
eval "$(rbenv init -)"
cd /mnt/c/dev/chatwoot-duedesk
export POSTGRES_HOST=127.0.0.1
"$@"
