#!/usr/bin/env bash
# setup.sh — One-time Reticulum demo setup
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}"; }
ok()     { echo -e "  ${GREEN}✓${NC} $*"; }
info()   { echo -e "  ${YELLOW}→${NC} $*"; }
err()    { echo -e "  ${RED}✗${NC} $*" >&2; exit 1; }

clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
 ____      _   _            _
|  _ \ ___| |_(_) ___ _   _| |_   _ _ __ ___
| |_) / _ \ __| |/ __| | | | | | | | '_ ` _ \
|  _ <  __/ |_| | (__| |_| | | |_| | | | | | |
|_| \_\___|\__|_|\___|\__,_|_|\__,_|_| |_| |_|

  Cryptographic mesh networking. No IP. No servers. No accounts.
BANNER
echo -e "${NC}"

# ── Python / pip ───────────────────────────────────────────────────────────────
header "Checking Python"
command -v python3 &>/dev/null || err "Python 3 is required. Install via your package manager."

if command -v pip3 &>/dev/null; then
    PIP=pip3
elif python3 -m pip --version &>/dev/null 2>&1; then
    PIP="python3 -m pip"
elif command -v pip &>/dev/null; then
    PIP=pip
else
    err "pip not found. Run: python3 -m ensurepip --upgrade"
fi
ok "Python $(python3 --version | awk '{print $2}') + pip"

# ── Install packages ───────────────────────────────────────────────────────────
header "Installing Reticulum stack"
info "rns, rnsh, nomadnet, lxmf  (this may take a minute on first run)"
echo
$PIP install --upgrade rns rnsh nomadnet lxmf
echo
ok "All packages installed"

# ── Verify installs ────────────────────────────────────────────────────────────
header "Verifying installs"
for cmd in rnsh rnstatus nomadnet; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd found at $(command -v $cmd)"
    else
        # Try via python module path (some pip setups put bins in ~/.local/bin)
        info "$cmd not in PATH — adding ~/.local/bin to PATH check"
        export PATH="$HOME/.local/bin:$PATH"
        command -v "$cmd" &>/dev/null && ok "$cmd found" || info "$cmd still not found — you may need to add ~/.local/bin to your PATH"
    fi
done

# ── Reticulum config ───────────────────────────────────────────────────────────
header "Configuring Reticulum"
CONFIG_DIR="$HOME/.reticulum"
CONFIG_FILE="$CONFIG_DIR/config"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    info "Creating ~/.reticulum/config..."
    cat > "$CONFIG_FILE" << 'RNSCONF'
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
    ok "Config created with AutoInterface + TCP server on port 4965"
else
    ok "Existing config found at ~/.reticulum/config"
    if grep -q "TCPServerInterface" "$CONFIG_FILE"; then
        ok "TCP server interface already present"
    else
        info "Adding TCP server interface (port 4965) to existing config..."
        printf '\n  [[TCP Server Interface]]\n    type = TCPServerInterface\n    enabled = Yes\n    listen_ip = 0.0.0.0\n    listen_port = 4965\n' >> "$CONFIG_FILE"
        ok "TCP server interface added"
    fi
fi

# ── Generate persistent demo identity ─────────────────────────────────────────
header "Creating demo identity"
IDENTITY_FILE="$HOME/.reticulum/rnsh_demo_identity"
if [ -f "$IDENTITY_FILE" ]; then
    ok "Demo identity already exists (same hash across restarts)"
else
    info "Generating rnsh demo identity..."
    # rnsh -p with -i creates the identity file on first run if it doesn't exist
    # We use a small python script to safely generate it
    python3 - "$IDENTITY_FILE" << 'PYEOF'
import sys
import RNS

identity_file = sys.argv[1]
identity = RNS.Identity()
identity.to_file(identity_file)
print(f"  Identity saved to {identity_file}")
PYEOF
    ok "Demo identity created"
fi

# ── Local IP ───────────────────────────────────────────────────────────────────
LOCAL_IP=""
if command -v ip &>/dev/null; then
    LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)
fi
if [ -z "$LOCAL_IP" ] && command -v hostname &>/dev/null; then
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
fi
LOCAL_IP="${LOCAL_IP:-<run 'hostname -I' to find your IP>}"

# Save it for demo.sh to use
echo "$LOCAL_IP" > "$CONFIG_DIR/.demo_local_ip"

# ── Done ───────────────────────────────────────────────────────────────────────
header "Setup complete!"
echo
echo -e "  Machine IP:    ${BOLD}${LOCAL_IP}${NC}  (phones connect here)"
echo -e "  TCP port:      ${BOLD}4965${NC}"
echo -e "  Demo identity: ${BOLD}~/.reticulum/rnsh_demo_identity${NC}"
echo
echo -e "  ${BOLD}Next:${NC}"
echo -e "    Read the guide:  ${CYAN}less GUIDE.md${NC}"
echo -e "    Run the demo:    ${CYAN}./demo.sh${NC}"
echo
