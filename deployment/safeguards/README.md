# Travas de recursos do servidor

1. **Limites por container** e **rotacao de logs**: o compose em uso fica so'
   no servidor (`/opt/chatwoot/docker-compose.yaml`, imagem `chatwoot-duedesk`).
   Edite la: `logging` (max-size 20m, max-file 3), `mem_limit` e `cpus` por
   servico. A soma dos limites deve ficar abaixo da RAM do host (`free -h`).
2. **Rotacao de logs global** (cobre containers que nao estao no compose):
   copie `docker-daemon.json` para `/etc/docker/daemon.json` e rode
   `sudo systemctl restart docker`. Vale so' para containers criados depois.
3. **Guarda de disco**: ver o cabecalho de `disk-guard.sh` (cron a cada 15 min).
   Avisa em 80%, limpa descartaveis em 85% e faz limpeza forte em 92%.
   Nunca apaga volumes (banco, redis, arquivos enviados).
4. **Swap** (rede de seguranca contra OOM), se o servidor nao tiver:
   `sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
   e acrescente `/swapfile none swap sw 0 0` em `/etc/fstab`.
