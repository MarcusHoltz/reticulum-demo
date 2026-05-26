#!/usr/bin/env bash

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

export PATH="$HOME/.local/bin:$PATH"

if [ -d "/data" ]; then
    IDENTITY_FILE="/data/rnsh_demo_identity"
else
    IDENTITY_FILE="$HOME/.reticulum/rnsh_demo_identity"
fi

HASH_FILE="/tmp/rnsh_demo_hash"

# ── helpers ────────────────────────────────────────────────────────────────────

box() {
    local msg="$1"
    local line
    line=$(printf '═%.0s' $(seq 1 $(( ${#msg} + 4 ))))
    echo -e "${CYAN}╔${line}╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${msg}${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}╚${line}╝${NC}"
}

sep()  { echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"; }
pause() {
    echo
    echo -e "  ${DIM}Press any key to continue...${NC}"
    read -r -n 1 -s
}

get_local_ip() {
    local ip=""
    if command -v ip &>/dev/null; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)
    fi
    [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    echo "${ip:-unknown}"
}

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        if [ -d "/data" ]; then
            echo -e "\n  ${YELLOW}$1 not found — try:${NC} docker compose up --build\n"
        else
            echo -e "\n  ${YELLOW}$1 not found — run:${NC} ./setup.sh\n"
        fi
        exit 1
    fi
}

# ── menu ───────────────────────────────────────────────────────────────────────

do_menu() {
    clear
    box "Reticulum Demo"
    echo
    echo -e "  Reticulum is a cryptographic mesh network. Your address is a hash"
    echo -e "  of your public key — not an IP. No accounts, no servers, no DNS."
    echo -e "  This demo runs over WiFi. The same code works over LoRa at 1200 bps."
    echo
    sep
    echo -e "  ${BOLD}Demo 1 — Encrypted Remote Shell${NC}"
    echo -e "  ${DIM}Like SSH, but the destination is a cryptographic hash, not an IP.${NC}"
    echo -e "  ${DIM}Open a second browser tab at the same URL to get a second terminal.${NC}"
    echo
    echo -e "    ${CYAN}[1]${NC}  ${BOLD}This tab is Tab 1${NC} — start the shell server"
    echo -e "    ${CYAN}[2]${NC}  ${BOLD}This tab is Tab 2${NC} — connect to the server"
    echo
    sep
    echo -e "  ${BOLD}Demo 2 — Phone → Linux Encrypted Messaging${NC}"
    echo -e "  ${DIM}Send messages from Android (Sideband) to this terminal.${NC}"
    echo -e "  ${DIM}Invite friends — everyone connected can message each other.${NC}"
    echo
    echo -e "    ${CYAN}[3]${NC}  ${BOLD}Set up Sideband + start messaging${NC}"
    echo
    sep
    echo -e "  ${BOLD}Demo 3 — File Transfer: Phone → Linux${NC}"
    echo -e "  ${DIM}Send any file from Sideband — photo, document, anything.${NC}"
    echo -e "  ${DIM}It lands in a folder on this machine. You'll see it arrive live.${NC}"
    echo
    echo -e "    ${CYAN}[4]${NC}  ${BOLD}Start the file receiver${NC}"
    echo
    sep
    echo -e "  ${BOLD}Demo 4 — LoRa Mesh Radio${NC}"
    echo -e "  ${DIM}Everything above works over LoRa radio — kilometers of range,${NC}"
    echo -e "  ${DIM}no WiFi, no internet, no infrastructure at all.${NC}"
    echo
    echo -e "    ${CYAN}[5]${NC}  ${BOLD}See what that looks like${NC}"
    echo
    sep
    echo -e "  ${BOLD}Next Steps — Make It Permanent${NC}"
    echo -e "  ${DIM}Put this on your server. Get your family on it. Own your comms.${NC}"
    echo
    echo -e "    ${CYAN}[6]${NC}  ${BOLD}How to take this further${NC}"
    echo
    sep
    echo -e "  ${BOLD}Vanity Address Generator${NC}"
    echo -e "  ${DIM}Search for a custom address that starts with any hex prefix.${NC}"
    echo -e "  ${DIM}Makes your address memorable — like a username, but cryptographic.${NC}"
    echo
    echo -e "    ${CYAN}[7]${NC}  ${BOLD}Generate a vanity address${NC}"
    echo
    sep
    echo -e "  ${BOLD}What the Mesh Can See — Privacy & Metadata${NC}"
    echo -e "  ${DIM}Live demo: watch announces arrive in plaintext. See exactly what${NC}"
    echo -e "  ${DIM}any node in range can read — and what you can do about it.${NC}"
    echo
    echo -e "    ${CYAN}[8]${NC}  ${BOLD}Privacy & metadata demo${NC}"
    echo
    sep
    echo
    echo -e "  ${BOLD}Press 1 – 8${NC}"
    echo

    local key
    while true; do
        read -r -n 1 -s key
        case "$key" in
            1) do_server ; break ;;
            2) do_connect ; break ;;
            3) do_phone_chat ; break ;;
            4) do_files ; break ;;
            5) do_lora ; break ;;
            6) do_nextsteps ; break ;;
            7) do_vanity ; break ;;
            8) do_privacy ; break ;;
        esac
    done
}

# ── demo 1: server ─────────────────────────────────────────────────────────────

do_server() {
    require_cmd rnsh
    clear
    box "Demo 1 — Encrypted Remote Shell: Tab 1 (server)"
    echo
    echo -e "  This machine is about to listen for encrypted shell connections."
    echo -e "  The address is a ${BOLD}cryptographic hash${NC} — not an IP address."
    echo -e "  Reticulum routes the connection automatically."
    echo

    # Derive and display hash
    if [ -f "$IDENTITY_FILE" ]; then
        DEST_HASH=$(python3 - "$IDENTITY_FILE" << 'PYEOF'
import sys, RNS
identity = RNS.Identity.from_file(sys.argv[1])
# Static hash method — no running RNS instance required
try:
    h = RNS.Destination.hash(identity, "rnsh")
except (AttributeError, TypeError):
    # Fallback: connect to shared rnsd then create destination
    RNS.Reticulum()
    h = RNS.Destination(identity, RNS.Destination.IN, RNS.Destination.SINGLE, "rnsh").hash
print(RNS.hexrep(h, delimit=False))
PYEOF
        ) || DEST_HASH=""
    fi

    if [ -n "${DEST_HASH:-}" ]; then
        # Save hash so Tab 2 can connect without typing
        echo "$DEST_HASH" > "$HASH_FILE"

        sep
        echo
        echo -e "  ${BOLD}${GREEN}Destination hash (saved — Tab 2 will connect automatically):${NC}"
        echo
        echo -e "  ${BOLD}${MAGENTA}  ${DEST_HASH}  ${NC}"
        echo
        sep
    fi

    echo
    echo -e "  ${YELLOW}!${NC} Server running — switch to Tab 2 and press ${BOLD}2${NC} to connect."
    echo -e "  ${DIM}  Ctrl+C to stop the server.${NC}"
    echo

    sleep 1

    if [ -f "$IDENTITY_FILE" ]; then
        rnsh -l -n -i "$IDENTITY_FILE"
    else
        rnsh -l -n
    fi
}

# ── demo 1: connect ────────────────────────────────────────────────────────────

do_connect() {
    require_cmd rnsh
    clear
    box "Demo 1 — Encrypted Remote Shell: Tab 2 (client)"
    echo

    # Read hash from file (written by server tab) — no typing required
    local HASH="${1:-}"
    if [ -z "$HASH" ] && [ -f "$HASH_FILE" ]; then
        HASH=$(cat "$HASH_FILE")
    fi

    if [ -z "$HASH" ]; then
        echo -e "  ${YELLOW}!${NC} No server hash found yet."
        echo -e "  ${DIM}  Go to Tab 1 and press 1 to start the server first, then come back here.${NC}"
        echo
        pause
        do_menu
        return
    fi

    # Normalize: strip brackets/colons/spaces in case of manual paste
    HASH="${HASH//</}"; HASH="${HASH//>/}"; HASH="${HASH//:/}"; HASH="${HASH// /}"

    echo -e "  Connecting to:  ${BOLD}${MAGENTA}${HASH}${NC}"
    echo
    echo -e "  ${DIM}No IP address used. The hash is the address.${NC}"
    echo -e "  ${DIM}End-to-end encrypted from the first byte.${NC}"
    echo -e "  ${DIM}This identical command works over LoRa radio across kilometers.${NC}"
    echo
    sep
    echo
    echo -e "  ${YELLOW}!${NC} Connecting... (${DIM}type 'exit' or Ctrl+C to disconnect${NC})"
    echo

    sleep 1
    rnsh "$HASH"
}

# ── demo 4: lora mesh explainer ─────────────────────────────────────────────────

do_lora() {
    clear
    # ── page 1 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 4 — LoRa Mesh Radio  (1/4)"
    echo
    echo -e "  Everything you just saw works without WiFi."
    echo
    echo -e "  Swap the WiFi connection for a small radio module"
    echo -e "  and this whole demo runs across kilometres of open air."
    echo
    echo -e "  No towers. No internet. No subscription."
    echo -e "  Just two radios and the Reticulum stack you already have."
    echo
    sep
    echo
    echo -e "  ${BOLD}Right now (this demo — over WiFi):${NC}"
    echo
    echo -e "       ${CYAN}[Phone]${NC} ──── WiFi ──── ${CYAN}[This machine]${NC}"
    echo -e "                  50 metres"
    echo -e "                  needs your router"
    echo
    echo -e "  ${BOLD}With two LoRa radios:${NC}"
    echo
    echo -e "       ${CYAN}[Phone]${NC}                          ${CYAN}[This machine]${NC}"
    echo -e "          │ Bluetooth              USB/Serial │"
    echo -e "          ▼                                  ▼"
    echo -e "      ${MAGENTA}[RNode]${NC} ╌╌╌╌ LoRa radio ╌╌╌╌ ${MAGENTA}[RNode]${NC}"
    echo -e "                   up to 15 km"
    echo -e "                   no WiFi needed"
    echo
    sep
    echo
    echo -e "  ${DIM}press any key for next page${NC}"
    read -r -n 1 -s

    # ── page 2 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 4 — LoRa Mesh Radio  (2/4)"
    echo
    echo -e "  Nodes in between automatically extend the range."
    echo -e "  Each one relays packets — but can't read them."
    echo
    sep
    echo
    echo -e "  ${BOLD}A mesh across a neighbourhood:${NC}"
    echo
    echo -e "   ${MAGENTA}[yours]${NC}╌╌╌╌╌╌${MAGENTA}[neighbour]${NC}╌╌╌╌╌╌${MAGENTA}[their neighbour]${NC}╌╌╌╌╌╌${MAGENTA}[friend]${NC}"
    echo -e "    home        5 km            5 km               5 km"
    echo
    echo -e "              total distance: ~15 km, no infrastructure"
    echo
    sep
    echo
    echo -e "  ${BOLD}A mesh across a building or farm:${NC}"
    echo
    echo -e "                        ${MAGENTA}[rooftop]${NC}"
    echo -e "                       ╱          ╲"
    echo -e "              ${MAGENTA}[office A]${NC}        ${MAGENTA}[barn]${NC}"
    echo -e "             ╱                        ╲"
    echo -e "       ${MAGENTA}[basement]${NC}               ${MAGENTA}[field sensor]${NC}"
    echo
    echo -e "  ${DIM}  All encrypted. All zero-config. No WiFi access points.${NC}"
    echo
    sep
    echo
    echo -e "  ${DIM}press any key for next page${NC}"
    read -r -n 1 -s

    # ── page 3 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 4 — LoRa Mesh Radio  (3/4)"
    echo
    echo -e "  ${BOLD}What you can actually do with this:${NC}"
    echo
    echo -e "   ${GREEN}★${NC}  Shell into your home server from anywhere in the city"
    echo -e "      — the same ${BOLD}rnsh${NC} from Demo 1, over radio"
    echo
    echo -e "   ${GREEN}★${NC}  Message anyone on the mesh with Sideband"
    echo -e "      — no phone number, no SIM, no signal bars needed"
    echo
    echo -e "   ${GREEN}★${NC}  Keep communicating when the internet goes down"
    echo -e "      — outage, disaster, or just a dead router"
    echo
    echo -e "   ${GREEN}★${NC}  Cover a property with no monthly fee"
    echo -e "      — farm, warehouse, campus, boat"
    echo
    echo -e "   ${GREEN}★${NC}  One node with internet bridges the whole mesh"
    echo -e "      — everyone on the mesh gets connectivity through it"
    echo
    sep
    echo
    echo -e "  ${DIM}press any key for next page${NC}"
    read -r -n 1 -s

    # ── page 4 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 4 — LoRa Mesh Radio  (4/4)"
    echo
    echo -e "  ${BOLD}Hardware — pick one to get started:${NC}"
    echo
    echo -e "   ${CYAN}RNode${NC}       purpose-built, plug and play"
    echo -e "               unsigned.io/rnode  (~€60)"
    echo
    echo -e "   ${CYAN}Heltec LoRa 32 v3${NC}   cheap DIY, flash RNode firmware"
    echo -e "               heltec.org  (~\$20)"
    echo
    echo -e "   ${CYAN}LILYGO T-Beam${NC}   popular, has GPS built in"
    echo -e "               lilygo.cc  (~\$30)"
    echo
    echo -e "   ${CYAN}Meshtastic device${NC}   you may already own one"
    echo -e "               flash RNode firmware, works immediately"
    echo
    sep
    echo
    echo -e "  ${BOLD}You need two${NC} — one for the radio, one for the other end."
    echo -e "  Plug the first into this machine via USB. Done."
    echo
    echo -e "  ${DIM}The config gets one extra block for the radio interface.${NC}"
    echo -e "  ${DIM}Every hash, every command, every app stays exactly the same.${NC}"
    echo
    sep
    echo
    echo -e "  ${DIM}press any key to return to menu${NC}"
    read -r -n 1 -s
    do_menu
}

# ── demo 3: file transfer receiver ────────────────────────────────────────────

do_files() {
    clear
    python3 /demo/lxmf.py files
}

# ── demo 2: phone setup + chat receiver ───────────────────────────────────────

do_phone_chat() {
    clear
    box "Demo 2 — Phone → Linux Encrypted Messaging"

    LOCAL_IP=$(get_local_ip)

    echo
    echo -e "  ${BOLD}Step 1 — Install Sideband on your Android phone${NC}"
    echo -e "  ${DIM}  Download the APK from: github.com/markqvist/Sideband/releases${NC}"
    echo
    sep
    echo
    echo -e "  ${BOLD}Step 2 — Connect Sideband to this machine${NC}"
    echo
    echo -e "    Open Sideband  →  ☰ Menu  →  ${BOLD}Connectivity${NC}"
    echo
    echo -e "    Enable  ${BOLD}\"Connect via TCP\"${NC}"
    echo
    echo -e "    ${BOLD}TCP Host:${NC}  ${CYAN}${LOCAL_IP}${NC}"
    echo -e "    ${BOLD}TCP Port:${NC}  ${CYAN}4965${NC}"
    echo
    echo -e "    Tap  ${BOLD}\"Restart RNS Service\"${NC}"
    echo
    sep
    echo
    echo -e "  ${BOLD}Step 3 — Press any key when Sideband shows \"Connected\"${NC}"
    echo -e "  ${DIM}  (The receiver will start and show a QR code to scan)${NC}"

    pause

    clear
    python3 /demo/lxmf.py chat
}

# ── next steps ────────────────────────────────────────────────────────────────

do_nextsteps() {

    # ── page 1 ───────────────────────────────────────────────────────────────
    clear
    box "Next Steps  (1/4)"
    echo
    echo -e "  You just used an encrypted mesh network with no accounts,"
    echo -e "  no servers, and no phone numbers."
    echo
    echo -e "  This doesn't have to be a demo."
    echo
    echo -e "  Run it permanently on any machine you own and your whole"
    echo -e "  network — friends, family, devices — stays connected."
    echo -e "  Forever. For free."
    echo
    sep
    echo
    echo -e "  ${BOLD}What a permanent setup looks like:${NC}"
    echo
    echo -e "       ${CYAN}[Your Server / VPS]${NC}  ← always on, public IP"
    echo -e "              │"
    echo -e "       ┌──────┴──────┐"
    echo -e "       │             │"
    echo -e "   ${CYAN}[Your Phone]${NC}   ${CYAN}[Family Phones]${NC}"
    echo -e "                     │"
    echo -e "                ${CYAN}[Laptops]${NC}"
    echo
    echo -e "  Everyone has an encrypted address. No one has an account."
    echo -e "  Messages route through your server — not Google, not Apple."
    echo
    sep
    echo
    echo -e "  ${DIM}press any key  →${NC}"
    read -r -n 1 -s

    # ── page 2 ───────────────────────────────────────────────────────────────
    clear
    box "Next Steps  (2/4)"
    echo
    echo -e "  ${BOLD}Step 1 — Put it on a server or laptop${NC}"
    echo
    echo -e "  Any Linux machine works. Raspberry Pi, VPS, old laptop."
    echo -e "  One command installs everything:"
    echo
    echo -e "  ${CYAN}pip install rns rnsh nomadnet lxmf sideband${NC}"
    echo
    echo -e "  Then run the daemon:"
    echo
    echo -e "  ${CYAN}rnsd --daemon${NC}"
    echo
    sep
    echo
    echo -e "  ${BOLD}Make it start automatically:${NC}"
    echo
    echo -e "  ${DIM}  [Unit]${NC}"
    echo -e "  ${DIM}  Description=Reticulum daemon${NC}"
    echo -e "  ${DIM}  After=network.target${NC}"
    echo -e "  ${DIM}  [Service]${NC}"
    echo -e "  ${DIM}  ExecStart=/usr/local/bin/rnsd${NC}"
    echo -e "  ${DIM}  Restart=always${NC}"
    echo -e "  ${DIM}  [Install]${NC}"
    echo -e "  ${DIM}  WantedBy=multi-user.target${NC}"
    echo
    echo -e "  Save to ${DIM}/etc/systemd/system/rnsd.service${NC}"
    echo -e "  then: ${CYAN}systemctl enable --now rnsd${NC}"
    echo
    echo -e "  Your server is now a permanent Reticulum hub."
    echo -e "  Anyone who adds its IP can reach anyone else on it."
    echo
    sep
    echo
    echo -e "  ${DIM}press any key  →${NC}"
    read -r -n 1 -s

    # ── page 3 ───────────────────────────────────────────────────────────────
    clear
    box "Next Steps  (3/4)"
    echo
    echo -e "  ${BOLD}Step 2 — Get everyone on it${NC}"
    echo
    echo -e "  Send this to your friends and family:"
    echo
    sep
    echo
    echo -e "  ${GREEN}Android:${NC}"
    echo -e "  Install Sideband:"
    echo -e "  ${CYAN}github.com/markqvist/Sideband/releases${NC}"
    echo
    echo -e "  Open it → ☰ Menu → Connectivity"
    echo -e "  Enable ${BOLD}Connect via TCP${NC}"
    echo -e "  Enter your server's IP and port 4965"
    echo -e "  Tap ${BOLD}Restart RNS Service${NC}"
    echo
    echo -e "  ${DIM}They're on your mesh. That's it.${NC}"
    echo
    sep
    echo
    echo -e "  ${GREEN}Linux / Mac / Windows:${NC}"
    echo -e "  ${CYAN}pip install rns lxmf nomadnet${NC}"
    echo
    echo -e "  Add to ${DIM}~/.reticulum/config${NC}:"
    echo -e "  ${DIM}  [[My Server]]${NC}"
    echo -e "  ${DIM}    type        = TCPClientInterface${NC}"
    echo -e "  ${DIM}    enabled     = Yes${NC}"
    echo -e "  ${DIM}    target_host = your.server.ip${NC}"
    echo -e "  ${DIM}    target_port = 4965${NC}"
    echo
    echo -e "  Run ${CYAN}nomadnet${NC} to message anyone on the mesh."
    echo
    sep
    echo
    echo -e "  ${DIM}press any key  →${NC}"
    read -r -n 1 -s

    # ── page 4 ───────────────────────────────────────────────────────────────
    clear
    box "Next Steps  (4/4)"
    echo
    echo -e "  ${BOLD}More things to explore:${NC}"
    echo
    echo -e "  ${GREEN}★${NC}  ${BOLD}Nomad Network${NC}  — terminal messaging + mesh-hosted pages"
    echo -e "     ${CYAN}nomadnet${NC}  (already installed here)"
    echo
    echo -e "  ${GREEN}★${NC}  ${BOLD}RetiBBS${NC}  — bulletin board on the mesh, no internet needed"
    echo -e "     ${CYAN}github.com/RetiBBS/retibbs${NC}"
    echo
    echo -e "  ${GREEN}★${NC}  ${BOLD}Sideband Desktop${NC}  — same app, runs on Linux / Mac / Windows"
    echo -e "     ${CYAN}github.com/markqvist/Sideband${NC}"
    echo
    echo -e "  ${GREEN}★${NC}  ${BOLD}MeshChat${NC}  — browser-based LXMF chat UI, works with Sideband"
    echo -e "     ${CYAN}github.com/liamcottle/reticulum-meshchat${NC}"
    echo
    echo -e "  ${GREEN}★${NC}  ${BOLD}LoRa radios${NC}  — take it fully off-grid (see Demo 4)"
    echo
    sep
    echo
    echo -e "  ${BOLD}The project:${NC}  ${CYAN}reticulum.network${NC}"
    echo -e "  ${BOLD}Source:${NC}       ${CYAN}github.com/markqvist/Reticulum${NC}"
    echo -e "  ${BOLD}Community:${NC}    ${CYAN}github.com/markqvist/Reticulum/discussions${NC}"
    echo
    sep
    echo
    echo -e "  Your address is yours forever."
    echo -e "  It moves with you across WiFi, cellular, LoRa, satellite."
    echo -e "  No one can take it away. No company owns the network."
    echo
    sep
    echo
    echo -e "  ${DIM}press any key to return to menu${NC}"
    read -r -n 1 -s
    do_menu
}

# ── demo 7: vanity address ─────────────────────────────────────────────────────

do_vanity() {
    clear
    python3 /demo/lxmf.py vanity
    do_menu
}

# ── demo 8: privacy & metadata ────────────────────────────────────────────────

do_privacy() {
    # ── page 1 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 8 — What the Mesh Can See  (1/3)"
    echo
    echo -e "  Reticulum encrypts your messages."
    echo -e "  It does not hide ${BOLD}that you sent them${NC} or ${BOLD}who you sent them to${NC}."
    echo
    sep
    echo
    printf "  ${GREEN}%-33s${NC}  ${YELLOW}%s${NC}\n" "WHAT RETICULUM ENCRYPTS" "WHAT THE MESH CAN SEE"
    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
    printf "  ${GREEN}%-33s${NC}  ${YELLOW}%s${NC}\n" "Message content (after link)"    "Your nickname & destination hash"
    printf "  ${GREEN}%-33s${NC}  ${YELLOW}%s${NC}\n" "Identity (inside encrypted link)" "Who you're trying to reach"
    printf "  ${GREEN}%-33s${NC}  ${YELLOW}%s${NC}\n" ""                                "Your persistent node ID"
    printf "  ${GREEN}%-33s${NC}  ${YELLOW}%s${NC}\n" ""                                "That you sent anything at all"
    echo
    sep
    echo
    echo -e "  ${BOLD}How it leaks:${NC} Before a message is sent, your node broadcasts"
    echo -e "  a plaintext ${BOLD}announce${NC} (your nickname + address) and a ${BOLD}path request${NC}"
    echo -e "  (which destination you want to reach). Any node in range sees both."
    echo
    echo -e "  ${DIM}This is how routing works — by design. Not a bug.${NC}"
    echo
    sep
    echo
    echo -e "  ${DIM}press any key — next: live sniffer →${NC}"
    read -r -n 1 -s

    # ── page 2 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 8 — What the Mesh Can See  (2/3)"
    echo
    echo -e "  ${BOLD}Live announce sniffer${NC}"
    echo -e "  ${DIM}What any passive node on this mesh can read right now:${NC}"
    echo
    sep
    echo
    python3 /demo/lxmf.py privacy
    sep
    echo
    echo -e "  ${DIM}press any key — next: what to do about it →${NC}"
    read -r -n 1 -s

    # ── page 3 ──────────────────────────────────────────────────────────────
    clear
    box "Demo 8 — What the Mesh Can See  (3/3)"
    echo
    echo -e "  ${BOLD}Mitigations${NC}"
    echo
    printf "  ${CYAN}%-30s${NC}  %s\n" "IFAC (interface auth codes)"  "Only your peers can join the mesh segment"
    printf "  ${CYAN}%-30s${NC}  %s\n" "Skip announces"               "Exchange hashes out-of-band; don't broadcast"
    printf "  ${CYAN}%-30s${NC}  %s\n" "Separate node per identity"   "Breaks the persistent node-ID linkage"
    printf "  ${CYAN}%-30s${NC}  %s\n" "Tunnel over I2P or Tor"       "Hides Reticulum metadata from the carrier"
    echo
    sep
    echo
    echo -e "  ${BOLD}Honest positioning:${NC}"
    echo
    echo -e "  Plain TCP/IP   ${YELLOW}→${NC}  on-path node sees ${BOLD}both IP addresses${NC} directly"
    echo -e "  Reticulum      ${YELLOW}→${NC}  on-path node sees ${BOLD}dest hash, node ID, nickname${NC}"
    echo -e "  Tor / I2P      ${YELLOW}→${NC}  on-path relay sees ${BOLD}adjacent hop only${NC} — not endpoints"
    echo
    echo -e "  Reticulum is a great ${BOLD}encrypted mesh protocol${NC}."
    echo -e "  It is not an anonymity network."
    echo -e "  For high-stakes anonymity, layer on ${BOLD}I2P${NC} or ${BOLD}Tor${NC}."
    echo
    sep
    echo
    echo -e "  ${DIM}press any key to return to menu${NC}"
    read -r -n 1 -s
    do_menu
}

# ── dispatch ───────────────────────────────────────────────────────────────────

case "${1:-menu}" in
    menu|help|--help|-h)  do_menu ;;
    server)               do_server ;;
    connect)              do_connect "${2:-}" ;;
    chat)                 clear; python3 /demo/lxmf.py chat ;;
    phone)                do_phone_chat ;;
    lora)                 do_lora ;;
    files)                do_files ;;
    next|nextsteps)       do_nextsteps ;;
    vanity)               do_vanity ;;
    privacy)              do_privacy ;;
    status)               rnstatus ;;
    *)
        echo -e "\n  ${YELLOW}Unknown command:${NC} $1"
        do_menu
        ;;
esac
