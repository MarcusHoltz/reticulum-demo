#!/usr/bin/env bash
# entrypoint.sh — Reticulum demo container startup
set -euo pipefail

DATA_DIR="/data"
RNS_DIR="/root/.reticulum"

# ── Persistent Reticulum data (on the named volume) ───────────────────────────
mkdir -p "$DATA_DIR" "$RNS_DIR"

# Symlink RNS storage into the persistent volume so identity/keys survive restarts
if [ ! -L "$RNS_DIR/storage" ]; then
    mkdir -p "$DATA_DIR/storage"
    ln -sf "$DATA_DIR/storage" "$RNS_DIR/storage"
fi

# ── Reticulum config ───────────────────────────────────────────────────────────
if [ ! -f "$RNS_DIR/config" ]; then
    cat > "$RNS_DIR/config" << 'RNSCONF'
[reticulum]
  share_instance = Yes
  shared_instance_port = 37428
  enable_transport = No
  out_of_band_enabled = No
  use_implicit_proof = Yes
  allow_probes = No
  panic_on_interface_error = No

[logging]
  loglevel = 4

[interfaces]

  [[AutoInterface]]
    type = AutoInterface
    enabled = Yes

  [[TCP Server Interface]]
    type = TCPServerInterface
    enabled = Yes
    listen_ip = 0.0.0.0
    listen_port = 4965
RNSCONF
    echo "[entrypoint] Reticulum config written to $RNS_DIR/config"
fi

# ── Persistent demo identity ───────────────────────────────────────────────────
IDENTITY_FILE="$DATA_DIR/rnsh_demo_identity"
if [ ! -f "$IDENTITY_FILE" ]; then
    echo "[entrypoint] Generating persistent rnsh identity..."
    python3 - "$IDENTITY_FILE" << 'PYEOF'
import sys, RNS
identity = RNS.Identity()
identity.to_file(sys.argv[1])
print(f"[entrypoint] Identity saved: {sys.argv[1]}")
PYEOF
fi

# ── Start Reticulum daemon ─────────────────────────────────────────────────────
# rnsd runs in the background so the TCP interface is always up.
# Phones can connect on port 4965 as soon as the container starts.
echo "[entrypoint] Starting Reticulum daemon (port 4965 open for phones)..."
rnsd --daemon 2>/dev/null || rnsd &
sleep 1

# ── Print startup info to container logs ──────────────────────────────────────
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null \
    | awk '/src/{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' \
    || echo "unknown")

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Reticulum Demo — container ready                 ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Browser terminal:  http://localhost:7681                ║"
echo "║  Phone TCP port:    ${LOCAL_IP}:4965                     ║"
echo "║                                                          ║"
echo "║  Open TWO browser tabs for the two-terminal demo:        ║"
echo "║    Tab 1: ./demo.sh server                               ║"
echo "║    Tab 2: ./demo.sh connect <hash>                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Kiosk wrapper (written at runtime so we don't need a separate file) ───────
# Ignores SIGINT/SIGQUIT/SIGTSTP so no keypress can escape the demo loop.
# Python's subprocess uses restore_signals=True by default, so Ctrl+C still
# works normally inside the demos themselves.
cat > /tmp/kiosk.py << 'PYEOF'
import os, signal, subprocess, time
signal.signal(signal.SIGINT,  signal.SIG_IGN)
signal.signal(signal.SIGQUIT, signal.SIG_IGN)
signal.signal(signal.SIGTSTP, signal.SIG_IGN)
ENV = {
    **os.environ,
    "TERM":      "xterm-256color",
    "COLORTERM": "truecolor",
    "PATH":      "/root/.local/bin:" + os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin"),
    "PS1":       r"\[\033[0;36m\][reticulum]\[\033[0m\] \[\033[1m\]\w\[\033[0m\] \$ ",
}
CMD = ["bash", "--norc", "--noprofile", "-c",
       "stty susp undef quit undef 2>/dev/null; cd /demo && ./demo.sh"]
while True:
    subprocess.run(CMD, env=ENV)
    time.sleep(0.1)
PYEOF

# ── Start ttyd (foreground, PID 1) ────────────────────────────────────────────
echo "[entrypoint] Starting ttyd on port 7681..."
exec ttyd \
    --port 7681 \
    --writable \
    --interface 0.0.0.0 \
    -t fontSize=15 \
    -t 'theme={"background":"#0d1117","foreground":"#c9d1d9","cursor":"#58a6ff"}' \
    python3 /tmp/kiosk.py
