#!/usr/bin/env bash
# Guarda de recursos do servidor: limpa o que e' seguro limpar quando o disco
# enche e registra um aviso antes de chegar a 100%.
#
# Instalar (como root ou usuario do docker):
#   sudo install -m 755 deployment/safeguards/disk-guard.sh /usr/local/bin/disk-guard
#   echo '*/15 * * * * root /usr/local/bin/disk-guard >> /var/log/disk-guard.log 2>&1' | sudo tee /etc/cron.d/disk-guard
#
# NUNCA toca em volumes (postgres_data, redis_data, storage_data): so' imagens
# paradas, cache de build, logs do sistema e dumps antigos.
set -u

WARN=${DISK_WARN_PCT:-80}      # so' avisa
CLEAN=${DISK_CLEAN_PCT:-85}    # limpa o que e' descartavel
CRIT=${DISK_CRIT_PCT:-92}      # limpeza mais agressiva
MOUNT=${DISK_MOUNT:-/}
BACKUP_DIR=${BACKUP_DIR:-/opt/chatwoot/backups}
BACKUP_KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}

ts() { date '+%F %T'; }
used() { df --output=pcent "$MOUNT" | tail -1 | tr -dc '0-9'; }

pct=$(used)
mem_avail=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
load=$(cut -d' ' -f1 /proc/loadavg)
echo "$(ts) disco=${pct}% mem_livre=${mem_avail}MB load=${load} cpus=$(nproc)"

[ "$pct" -lt "$WARN" ] && exit 0
echo "$(ts) AVISO: disco em ${pct}%"
docker system df 2>/dev/null | sed 's/^/    /'

if [ "$pct" -ge "$CLEAN" ]; then
  echo "$(ts) limpando descartaveis (imagens sem uso, cache de build, journal)"
  docker image prune -af --filter 'until=72h' >/dev/null 2>&1
  docker builder prune -af --filter 'until=72h' >/dev/null 2>&1
  journalctl --vacuum-size=200M >/dev/null 2>&1
  apt-get clean >/dev/null 2>&1
  [ -d "$BACKUP_DIR" ] && find "$BACKUP_DIR" -type f -mtime +"$BACKUP_KEEP_DAYS" -delete
fi

if [ "$(used)" -ge "$CRIT" ]; then
  echo "$(ts) CRITICO: disco ainda em $(used)% - limpeza agressiva"
  docker system prune -af >/dev/null 2>&1     # volumes NAO entram (sem --volumes)
  journalctl --vacuum-size=50M >/dev/null 2>&1
  # logs de container que escaparam da rotacao
  find /var/lib/docker/containers -name '*-json.log' -size +100M -exec truncate -s 0 {} \;
fi

echo "$(ts) disco apos limpeza: $(used)%"
