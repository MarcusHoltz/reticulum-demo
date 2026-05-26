#!/usr/bin/env python3
"""
lxmf.py — LXMF demos: encrypted chat, file transfer, vanity address generator.
Usage:  python3 lxmf.py [chat|files|vanity|privacy]
"""

import os, subprocess, sys, time

sys.path.insert(0, os.path.expanduser("~/.local/bin"))

import RNS
import LXMF

CYAN    = "\033[0;36m"
GREEN   = "\033[0;32m"
YELLOW  = "\033[1;33m"
MAGENTA = "\033[0;35m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
NC      = "\033[0m"

DATA_ROOT    = "/data" if os.path.isdir("/data") else os.path.expanduser("~/.reticulum")
RECEIVE_DIR  = "/received"

# ── shared helpers ─────────────────────────────────────────────────────────────

def box(msg):
    line = "═" * (len(msg) + 4)
    print(f"{CYAN}╔{line}╗{NC}")
    print(f"{CYAN}║{NC}  {BOLD}{msg}{NC}  {CYAN}║{NC}")
    print(f"{CYAN}╚{line}╝{NC}")

def sep():
    print(f"  {DIM}{'─'*51}{NC}")

def keypress():
    import tty, termios
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setcbreak(fd)
        return sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

def show_qr(data):
    try:
        import qrcode
        qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_L, border=1)
        qr.add_data(data)
        qr.make(fit=True)
        qr.print_ascii(invert=True)
    except Exception:
        pass

def get_local_ip():
    try:
        out = subprocess.check_output(
            ["ip", "route", "get", "1.1.1.1"], stderr=subprocess.DEVNULL
        ).decode()
        tokens = out.split()
        return tokens[tokens.index("src") + 1]
    except Exception:
        return "unknown"

def rns_start():
    print(f"  {DIM}Connecting to Reticulum...{NC}", end="", flush=True)
    RNS.Reticulum()
    print(f" {GREEN}ready{NC}\n")

def load_identity(subdir):
    storage = os.path.join(DATA_ROOT, subdir)
    os.makedirs(storage, exist_ok=True)
    id_path = os.path.join(storage, "identity")
    if os.path.exists(id_path):
        return RNS.Identity.from_file(id_path), storage
    identity = RNS.Identity()
    identity.to_file(id_path)
    return identity, storage

def lxmf_addr(identity, node=None):
    try:
        return RNS.hexrep(RNS.Destination.hash(identity, "lxmf", "delivery"), delimit=False)
    except (AttributeError, TypeError):
        dest = getattr(node, "destination", node)
        return RNS.hexrep(dest.hash, delimit=False)


# ── demo 3: encrypted chat ─────────────────────────────────────────────────────

def run_chat():
    rns_start()
    identity, storage = load_identity("lxmf_chat")
    router = LXMF.LXMRouter(storagepath=storage)
    node   = router.register_delivery_identity(identity, display_name="Linux Demo")

    def on_message(message):
        ts      = time.strftime("%H:%M:%S")
        sender  = RNS.hexrep(message.source_hash, delimit=False)
        content = ""
        if message.content:
            try:    content = message.content.decode("utf-8").strip()
            except: content = repr(message.content)
        print()
        print(f"  {GREEN}{'─'*51}{NC}")
        print(f"  {BOLD}{GREEN}  ★  Message received  {ts}  {NC}")
        print(f"  {GREEN}{'─'*51}{NC}")
        print()
        print(f"  {BOLD}{YELLOW}{content}{NC}")
        print()
        print(f"  {DIM}from: {sender}{NC}")
        print(f"  {GREEN}{'─'*51}{NC}")
        print()

    router.register_delivery_callback(on_message)

    addr     = lxmf_addr(identity, node)
    local_ip = get_local_ip()

    # ── page 1 ────────────────────────────────────────────────────────────────
    box("Demo 3 — Encrypted Messaging  (1/2)")
    print()
    print(f"  Scan this QR code in Sideband to open a conversation")
    print(f"  with this Linux machine.")
    print()
    sep()
    print()
    show_qr(f"lxm://{addr}")
    print()
    sep()
    print()
    print(f"  {BOLD}In Sideband on your phone:{NC}")
    print()
    print(f"  {GREEN}1.{NC} Tap {BOLD}Conversations{NC}  →  {BOLD}+{NC}  →  {BOLD}New Conversation{NC}")
    print(f"  {GREEN}2.{NC} Tap the {BOLD}QR icon{NC} and scan the code above")
    print(f"  {GREEN}3.{NC} Type a message and send it — it appears here")
    print()
    sep()
    print()
    print(f"  {DIM}press any key to see how to invite friends →{NC}")
    keypress()

    # ── page 2 ────────────────────────────────────────────────────────────────
    print()
    box("Demo 3 — Encrypted Messaging  (2/2)")
    print()
    print(f"  This machine is a Reticulum hub.")
    print(f"  Anyone who connects to it over TCP joins the same")
    print(f"  encrypted mesh — and can message {BOLD}each other{NC} directly.")
    print()
    print(f"  No accounts. No phone numbers. Just the hash.")
    print()
    sep()
    print()
    print(f"  {BOLD}Share this with friends — they add it in Sideband:{NC}")
    print()
    print(f"  {BOLD}Address:  {CYAN}{local_ip}{NC}")
    print(f"  {BOLD}Port:     {CYAN}4965{NC}")
    print()
    show_qr(f"{local_ip}:4965")
    print()
    sep()
    print()
    print(f"  {BOLD}Their steps in Sideband:{NC}")
    print()
    print(f"  {GREEN}1.{NC} ☰ Menu  →  {BOLD}Connectivity{NC}")
    print(f"  {GREEN}2.{NC} Enable {BOLD}Connect via TCP{NC}")
    print(f"  {GREEN}3.{NC} Host: {CYAN}{local_ip}{NC}   Port: {CYAN}4965{NC}")
    print(f"  {GREEN}4.{NC} Tap {BOLD}Restart RNS Service{NC}")
    print()
    sep()
    print()
    print(f"  {BOLD}Once they're connected:{NC}")
    print()
    print(f"  {GREEN}★{NC}  In Sideband → {BOLD}Announce Stream{NC} — see who's online")
    print(f"  {GREEN}★{NC}  Tap any name → start an encrypted conversation")
    print(f"  {GREEN}★{NC}  Messages go phone-to-phone through this hub")
    print(f"  {GREEN}★{NC}  You can all message this Linux machine too")
    print()
    sep()
    print()
    print(f"  {BOLD}Waiting for messages...{NC}  {DIM}(Ctrl+C to quit){NC}")
    print()

    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print(f"\n  {DIM}Done.{NC}\n")


# ── demo 4: file transfer ──────────────────────────────────────────────────────

def _save_file(filename, data):
    filename = os.path.basename(filename) or f"file_{int(time.time())}"
    dest = os.path.join(RECEIVE_DIR, filename)
    if os.path.exists(dest):
        base, ext = os.path.splitext(filename)
        dest = os.path.join(RECEIVE_DIR, f"{base}_{int(time.time())}{ext}")
    with open(dest, "wb") as f:
        f.write(data)
    return dest

def _show_dir():
    print(f"\n  {BOLD}Files in {RECEIVE_DIR}:{NC}\n")
    try:
        result = subprocess.check_output(
            ["ls", "-alh", RECEIVE_DIR], stderr=subprocess.STDOUT
        ).decode().strip()
        for line in result.splitlines():
            print(f"    {DIM}{line}{NC}")
    except Exception:
        print(f"    {DIM}(empty){NC}")
    print()

def run_files():
    os.makedirs(RECEIVE_DIR, exist_ok=True)
    rns_start()
    identity, storage = load_identity("lxmf_files")
    router = LXMF.LXMRouter(storagepath=storage)
    node   = router.register_delivery_identity(identity, display_name="File Drop")

    def on_message(message):
        ts     = time.strftime("%H:%M:%S")
        sender = RNS.hexrep(message.source_hash, delimit=False)
        saved  = []

        if message.fields:
            for attachment in message.fields.get(LXMF.FIELD_FILE_ATTACHMENTS, []):
                try:    saved.append(_save_file(attachment[0], attachment[1]))
                except Exception as e:
                    print(f"\n  {YELLOW}! Could not save file: {e}{NC}")

            image = message.fields.get(LXMF.FIELD_IMAGE)
            if image:
                try:
                    img_type = image[0] if isinstance(image, (list, tuple)) else "jpeg"
                    img_data = image[1] if isinstance(image, (list, tuple)) else image
                    ext      = img_type.split("/")[-1].split("+")[0]
                    saved.append(_save_file(f"image_{int(time.time())}.{ext}", img_data))
                except Exception as e:
                    print(f"\n  {YELLOW}! Could not save image: {e}{NC}")

            audio = message.fields.get(LXMF.FIELD_AUDIO)
            if audio:
                try:
                    audio_data = audio[1] if isinstance(audio, (list, tuple)) else audio
                    saved.append(_save_file(f"audio_{int(time.time())}.ogg", audio_data))
                except Exception as e:
                    print(f"\n  {YELLOW}! Could not save audio: {e}{NC}")

        content = ""
        if message.content:
            try:    content = message.content.decode("utf-8").strip()
            except: pass

        print()
        sep()
        if saved:
            print(f"  {BOLD}{GREEN}  ★  File received  {ts}  {NC}")
            sep()
            print()
            for path in saved:
                size = os.path.getsize(path)
                print(f"  {GREEN}✓{NC}  {BOLD}{os.path.basename(path)}{NC}  {DIM}({size:,} bytes){NC}")
            if content:
                print()
                print(f"  {DIM}Message: {content}{NC}")
            _show_dir()
        elif content:
            print(f"  {BOLD}{GREEN}  ★  Message received  {ts}  {NC}")
            sep()
            print()
            print(f"  {BOLD}{YELLOW}{content}{NC}")
            print()
            print(f"  {DIM}from: {sender}{NC}")
            print()
        else:
            print(f"  {YELLOW}! Empty message from {sender}{NC}")

        print(f"  {DIM}Waiting for more...  (Ctrl+C to quit){NC}\n")

    router.register_delivery_callback(on_message)

    addr = lxmf_addr(identity, node)

    box("Demo 4 — File Transfer: Phone → Linux")
    print()
    sep()
    print(f"  {BOLD}Scan in Sideband to send files to this machine:{NC}")
    print()
    print(f"  {BOLD}{MAGENTA}  {addr}  {NC}")
    print()
    show_qr(f"lxm://{addr}")
    print()
    sep()
    print()
    print(f"  {BOLD}How to send a file from Sideband:{NC}")
    print()
    print(f"  {GREEN}1.{NC} Open the conversation with this machine")
    print(f"      {DIM}(scan QR above if you haven't already){NC}")
    print()
    print(f"  {GREEN}2.{NC} Tap the {BOLD}paperclip / attachment icon{NC} in the message bar")
    print()
    print(f"  {GREEN}3.{NC} Pick any file — photo, document, whatever")
    print()
    print(f"  {GREEN}4.{NC} Send it — it will appear below and land in:")
    print()
    print(f"      {CYAN}{RECEIVE_DIR}{NC}  {DIM}(mounted to your host machine){NC}")
    print()
    sep()
    print()
    _show_dir()
    print(f"  {BOLD}Waiting for files...{NC}  {DIM}(Ctrl+C to quit){NC}")
    print()

    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print(f"\n  {DIM}Done.{NC}\n")


# ── demo 8: privacy / metadata sniffer ────────────────────────────────────────

def run_privacy():
    rns_start()

    # Persistent transport identity — read from storage if Transport hasn't set it yet
    transport_id = ""
    try:
        if hasattr(RNS.Transport, "identity") and RNS.Transport.identity is not None:
            transport_id = RNS.hexrep(RNS.Transport.identity.hash, delimit=False)
    except Exception:
        pass
    if not transport_id:
        tid_path = os.path.join(DATA_ROOT, "storage", "transport_identity")
        if os.path.exists(tid_path):
            try:
                transport_id = RNS.hexrep(RNS.Identity.from_file(tid_path).hash, delimit=False)
            except Exception:
                pass

    print(f"  {BOLD}Persistent node ID (Transport.identity):{NC}")
    print(f"  {CYAN}{transport_id or '(check /data/storage/transport_identity)'}{NC}")
    print(f"  {DIM}This ID is in every path-request this node sends, visible to{NC}")
    print(f"  {DIM}first-hop neighbors — and links all destinations to one machine.{NC}")
    print()

    # Load the messaging identity to show what its announce contains.
    # We compute the delivery hash directly — no need to start an LXMRouter,
    # which would conflict if demo 3 is already running in another tab.
    identity, _ = load_identity("lxmf_chat")
    dest_hash    = RNS.Destination.hash(identity, "lxmf", "delivery")
    dest_hex     = RNS.hexrep(dest_hash, delimit=False)
    pub_hex      = identity.get_public_key().hex()
    nickname     = "Linux Demo"  # display_name set by demo 3
    ts           = time.strftime("%H:%M:%S")

    sep()
    print()
    print(f"  {BOLD}What this node broadcasts in plaintext when it announces:{NC}")
    print()
    print(f"  [{DIM}{ts}{NC}]  {MAGENTA}{dest_hex[:16]}..{NC}  {BOLD}{nickname}{NC}  {DIM}← any node in range sees this{NC}")
    print()
    print(f"  {DIM}destination hash  {dest_hex}{NC}")
    print(f"  {DIM}public key        {pub_hex[:32]}...{NC}")
    print(f"  {DIM}nickname          {nickname}{NC}")

    # Register handler to catch announces from other peers (Sideband, etc.)
    seen = []

    class AnnounceHandler:
        aspect_filter = None
        def received_announce(self, destination_hash, announced_identity, app_data):
            ts_      = time.strftime("%H:%M:%S")
            d_hex    = RNS.hexrep(destination_hash, delimit=False)[:16]
            name     = LXMF.display_name_from_app_data(app_data) or "(no nickname)"
            print(f"  [{DIM}{ts_}{NC}]  {MAGENTA}{d_hex}..{NC}  {BOLD}{name}{NC}  {DIM}[received]{NC}")
            seen.append(destination_hash)

    RNS.Transport.register_announce_handler(AnnounceHandler())

    print()
    sep()
    print()
    print(f"  {DIM}Listening for other nodes' announces...  (Ctrl+C or wait 45 s){NC}")
    print()

    try:
        deadline = time.time() + 45
        while time.time() < deadline:
            time.sleep(0.5)
        print(f"  {DIM}Done. Received {len(seen)} announce(s) from other nodes.{NC}")
    except KeyboardInterrupt:
        print(f"\n  {DIM}Done. Received {len(seen)} announce(s) from other nodes.{NC}")
    print()


# ── demo 7: vanity address ─────────────────────────────────────────────────────

def _vanity_worker(prefix, result_queue, counter):
    """Runs in a subprocess — no live RNS instance needed."""
    while True:
        identity = RNS.Identity()
        try:
            h = RNS.Destination.hash(identity, "lxmf", "delivery")
        except (AttributeError, TypeError):
            continue
        addr = RNS.hexrep(h, delimit=False)
        with counter.get_lock():
            counter.value += 1
        if addr.startswith(prefix):
            result_queue.put((addr, identity.get_private_key()))
            return

def run_vanity():
    import binascii, multiprocessing

    identity_out = os.path.join(DATA_ROOT, "lxmf_chat", "identity")
    os.makedirs(os.path.dirname(identity_out), exist_ok=True)

    box("Demo 7 — Vanity Address Generator")
    print()
    print(f"  Your Reticulum address is a cryptographic hash of your public key.")
    print(f"  Normally it's random. But you can search for one that starts with")
    print(f"  any prefix you like — just takes a bit of computation.")
    print()
    sep()
    print()
    print(f"  {BOLD}Roughly how long it takes:{NC}")
    print()
    print(f"  {DIM}2 chars{NC}  — instant  (1 in 256)")
    print(f"  {DIM}3 chars{NC}  — < 1 second")
    print(f"  {DIM}4 chars{NC}  — ~5–20 seconds")
    print(f"  {DIM}5 chars{NC}  — ~5–10 minutes")
    print(f"  {DIM}6 chars{NC}  — hours")
    print()
    print(f"  {YELLOW}!{NC}  Hex characters only: 0–9 and a–f")
    print()
    sep()
    print()

    valid = set("0123456789abcdef")
    while True:
        try:
            raw = input(f"  {BOLD}Enter prefix (2–5 hex chars):{NC} ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print(f"\n  {DIM}Cancelled.{NC}\n")
            return
        if not raw:
            continue
        if not all(c in valid for c in raw):
            print(f"  {YELLOW}!{NC}  Only hex characters (0–9, a–f) are allowed.\n")
            continue
        if len(raw) < 2:
            print(f"  {YELLOW}!{NC}  Please enter at least 2 characters.\n")
            continue
        if len(raw) > 5:
            print(f"  {YELLOW}!{NC}  Prefix longer than 5 chars could take hours — try 4 or less.\n")
            continue
        prefix = raw
        break

    n_workers    = max(1, multiprocessing.cpu_count())
    result_queue = multiprocessing.Queue()
    counter      = multiprocessing.Value("L", 0)

    print()
    sep()
    print()
    print(f"  Searching for an address starting with  {BOLD}{MAGENTA}{prefix}{NC}")
    print(f"  Using {n_workers} CPU core{'s' if n_workers != 1 else ''} in parallel.")
    print()
    print(f"  {DIM}Ctrl+C to cancel{NC}")
    print()

    processes = [
        multiprocessing.Process(target=_vanity_worker, args=(prefix, result_queue, counter), daemon=True)
        for _ in range(n_workers)
    ]
    for p in processes:
        p.start()

    start     = time.time()
    addr      = None
    key_bytes = None

    try:
        while True:
            try:
                addr, key_bytes = result_queue.get(timeout=0.5)
                break
            except Exception:
                elapsed = time.time() - start
                tried   = counter.value
                rate    = tried / elapsed if elapsed > 0 else 0
                print(f"\r  {DIM}Tried {tried:,}  |  {rate:,.0f}/s  |  {elapsed:.1f}s{NC}   ", end="", flush=True)
    except KeyboardInterrupt:
        print(f"\n\n  {DIM}Search cancelled.{NC}\n")
    finally:
        for p in processes:
            p.terminate()
        for p in processes:
            p.join()

    if addr is None:
        return

    elapsed = time.time() - start
    tried   = counter.value
    key_hex = binascii.hexlify(key_bytes).decode()

    print(f"\r  {' '*60}\r", end="")
    print()
    sep()
    print()
    print(f"  {BOLD}{GREEN}  ★  Found it!  {NC}")
    print()
    print(f"  {BOLD}Address:{NC}  {BOLD}{MAGENTA}  {addr}  {NC}")
    print()
    print(f"  {DIM}Searched {tried:,} identities in {elapsed:.1f}s ({tried/elapsed:,.0f}/s){NC}")
    print()
    sep()
    print()
    print(f"  {BOLD}What would you like to do?{NC}")
    print()
    print(f"  {CYAN}[s]{NC}  Save as Demo 3/4 messaging identity")
    print(f"      {DIM}Demo 3 & 4 will use this address permanently.{NC}")
    print(f"      {DIM}Old identity is backed up first.{NC}")
    print()
    print(f"  {CYAN}[e]{NC}  Export private key as QR code")
    print(f"      {DIM}Shows the key so you can save it outside this demo.{NC}")
    print(f"      {DIM}Import it into Sideband Desktop, another RNS node, etc.{NC}")
    print()
    print(f"  {CYAN}[b]{NC}  Both — save AND export")
    print()
    print(f"  {CYAN}[n]{NC}  Discard — just admire it and move on")
    print()

    choice = ""
    while choice not in ("s", "e", "b", "n", "\x03"):
        choice = keypress().lower()

    print()
    do_save   = choice in ("s", "b")
    do_export = choice in ("e", "b")

    if choice in ("\x03", "n"):
        print(f"  {DIM}Identity discarded. Your current address is unchanged.{NC}")

    if do_save:
        if os.path.exists(identity_out):
            backup = identity_out + ".bak"
            os.replace(identity_out, backup)
            print(f"  {DIM}Old identity backed up to {backup}{NC}")
        RNS.Identity.from_bytes(key_bytes).to_file(identity_out)
        print()
        print(f"  {GREEN}✓{NC}  Saved to {identity_out}")
        print(f"      Start Demo 3 or Demo 4 to use this address.")

    if do_export:
        qr_payload = f"Address: {addr}\nPrivate key: {key_hex}"
        print()
        sep()
        print()
        print(f"  {BOLD}Private Key Export{NC}")
        print()
        print(f"  {YELLOW}Keep this secret.{NC} Anyone with this key controls your address.")
        print()
        show_qr(qr_payload)
        print()
        print(f"  {BOLD}Address:{NC}")
        print(f"  {MAGENTA}{addr}{NC}")
        print()
        print(f"  {BOLD}Private key:{NC}")
        print(f"  {CYAN}{key_hex[:64]}{NC}")
        print(f"  {CYAN}{key_hex[64:]}{NC}")
        print()
        sep()
        print()
        print(f"  {BOLD}To restore on any RNS node:{NC}")
        print()
        print(f"  {DIM}python3 -c \"import RNS, binascii; \\{NC}")
        print(f"  {DIM}  i = RNS.Identity.from_bytes(binascii.unhexlify('<key>')); \\{NC}")
        print(f"  {DIM}  i.to_file('/path/to/identity')\"{NC}")
        print()
        print(f"  {DIM}Or in Sideband Desktop: Settings → Identity → Import{NC}")

    print()
    sep()
    print()
    print(f"  {DIM}Press any key to return to menu...{NC}")
    keypress()


# ── dispatch ──────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    {
        "chat":    run_chat,
        "files":   run_files,
        "vanity":  run_vanity,
        "privacy": run_privacy,
    }.get(sys.argv[1] if len(sys.argv) > 1 else "chat", run_chat)()
