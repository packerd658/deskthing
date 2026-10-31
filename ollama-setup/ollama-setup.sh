#!/usr/bin/env bash
# Run on the computer that has Ollama (Linux). Makes Ollama reachable by the Desk Thing,
# opens the firewall port, and keeps a laptop on with the lid closed. Needs sudo.
set -e
echo "== Desk Thing: setting up Ollama on $(hostname) =="
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/desk-thing.conf <<'CONF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_KEEP_ALIVE=30m"
CONF
systemctl daemon-reload
systemctl restart ollama
echo "[ok] Ollama now accepts the Desk Thing (all network devices + browsers)"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then ufw allow 11434/tcp >/dev/null; echo "[ok] firewall: opened port 11434"; else echo "[ok] firewall: ufw not active, nothing to open"; fi
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/desk-thing.conf <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
CONF
systemctl restart systemd-logind || true
echo "[ok] laptop stays on with the lid closed"
sleep 3
echo
echo "== Check =="
systemctl show ollama --property=Environment | tr ' ' '\n' | grep OLLAMA_ || true
echo -n "Listening: "; ss -ltnp 2>/dev/null | grep 11434 | awk '{print $4}' | head -1
echo -n "Ollama says: "; curl -s --max-time 5 http://127.0.0.1:11434 ; echo
echo "Addresses: $(hostname -I)"
echo "Models installed:"; ollama list 2>/dev/null || curl -s http://127.0.0.1:11434/api/tags
echo
echo "== Done =="
