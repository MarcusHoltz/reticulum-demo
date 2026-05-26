# Reticulum Demo

Reticulum is a cryptographic mesh networking stack. Your address is the hash of your public key — not an IP, not a domain. Everything is end-to-end encrypted by default.

It runs over WiFi, LoRa radio, serial cables, or anything else that moves bits.

This repo gives you a self-contained demo in Docker. Open a browser, press a number.


* * *

![Reticulum is a cryptographic mesh networking stack](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/header/header--network--reticulum-demo.jpg "not an IP, not a domain")

* * *

## Requirements

- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/)
- A modern browser
- Optionally: 
- an Android phone on the same WiFi
- a domain for HTTPS

---

## Quick start

```bash
docker compose up --build
```

First run builds the image (~2–3 min). Then open **http://<your_ip_or_domain_here>:7681** — you get an interactive menu. No typing required.

---

## What's in the menu

```
[1]  Encrypted Remote Shell — Tab 1 (start server)
[2]  Encrypted Remote Shell — Tab 2 (connect)
[3]  Phone → Linux Encrypted Messaging
[4]  File Transfer: Phone → Linux
[5]  LoRa Mesh Radio — conceptual explainer
[6]  Next Steps — make it permanent
[7]  Vanity Address Generator
[8]  What the Mesh Can See — Privacy & Metadata
```

**Demo 1 & 2** — Open two browser tabs at the same URL. Tab 1 presses `1` to start an rnsh server. Tab 2 presses `2` to connect. The hash is shared automatically — no copying, no typing. You get an encrypted shell between the two tabs routed over Reticulum. This identical command works over LoRa radio across kilometers. 

**Demo 3** — Connects your Android phone (Sideband app) to this machine over LXMF, the encrypted mesh messaging protocol. Shows a QR code to scan. Messages appear live in the terminal. A second page shows how to invite friends so they can message each other through this hub.

**Demo 4** — Receive any file from Sideband (photo, document, audio) into a host-mounted folder (`./received/`). Files appear live as they land.

**Demo 5** — No code, no setup. A visual walkthrough of how LoRa radios extend everything above to kilometers of range with no WiFi and no internet.

**Demo 6** — How to run this permanently on a server, get family and friends on it, and what else exists in the ecosystem.

**Demo 7** — Vanity address generator. Search for a Reticulum address that starts with any hex prefix. Uses all CPU cores. Found addresses can be saved as your permanent messaging identity and/or exported as a QR code with the private key.

**Demo 8** — Privacy & metadata explainer. Shows what Reticulum encrypts (message content) versus what the mesh can see in plaintext (your nickname, destination hash, persistent node ID, and who you're trying to reach). Includes a live announce sniffer showing exactly what any passive node in range reads off the wire, plus a comparison against Tor/I2P and concrete mitigations (IFAC, skipping announces, tunneling).

---

## Phone setup (for Demo 3 & 4)

1. Install **Sideband** on Android: [github.com/markqvist/Sideband/releases](https://github.com/markqvist/Sideband/releases)

2. Open Sideband → **☰ Menu → Connectivity**

3. Enable **Connect via TCP** — host: your machine's IP, port: `4965`

4. Tap **Restart RNS Service**

5. Press `3` or `4` in the demo menu and scan the QR code shown

---

## HTTPS / public access (optional)

A `Caddyfile` is included for putting the terminal behind a reverse proxy with automatic TLS. Edit the domain placeholder, then:

```bash
docker compose up --build
```

Caddy handles the ACME HTTP challenge, cert renewal, and HTTP→HTTPS redirect.

Port 80 and 443 must be reachable from the internet for cert issuance.

---

## Bare metal (no Docker)

```bash
./setup.sh
./demo.sh
```

Installs the Reticulum stack via pip and runs the same menu natively.

---

## Stopping

```bash
docker compose down
```

Identities are stored in a named Docker volume (`reticulum-data`) so your addresses stay the same across restarts. To start fresh:

```bash
docker compose down -v
docker compose up --build
```

---

## How it works

```
Browser (ttyd terminal at :7681)
    │
    └── kiosk loop → demo.sh menu → lxmf.py / rnsh
                                         │
                              Reticulum daemon (rnsd)
                                         │
                              ┌──────────┴──────────┐
                         AutoInterface          TCPServerInterface
                        (mDNS / LAN)            (phones → :4965)
```

`network_mode: host` is required — Reticulum's AutoInterface uses mDNS multicast which doesn't work through Docker bridge networking.

---

## Going further

- [reticulum.network](https://reticulum.network) — project home, full manual
- [Sideband](https://github.com/markqvist/Sideband) — Android/Desktop LXMF client
- [MeshChat](https://github.com/liamcottle/reticulum-meshchat) — browser-based LXMF chat UI
- [rnsh](https://github.com/acehoss/rnsh) — encrypted shell over Reticulum
- [NomadNet](https://github.com/markqvist/NomadNet) — terminal mesh browser and messaging
