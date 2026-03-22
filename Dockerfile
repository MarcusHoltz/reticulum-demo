FROM python:3.12-slim

# ── System deps ────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        iproute2 \
        procps \
        less \
        bash \
    && rm -rf /var/lib/apt/lists/*

# ── ttyd (static binary — no extra deps needed) ────────────────────────────────
# Pinned release; update ARG to bump version
ARG TTYD_VERSION=1.7.7
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
        x86_64)          TTYD_ARCH=x86_64   ;; \
        aarch64|arm64)   TTYD_ARCH=aarch64  ;; \
        armv7l)          TTYD_ARCH=arm       ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSL \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" \
        -o /usr/local/bin/ttyd; \
    chmod +x /usr/local/bin/ttyd

# ── Reticulum stack ────────────────────────────────────────────────────────────
RUN pip install --no-cache-dir rns rnsh nomadnet lxmf qrcode

# ── Demo files ─────────────────────────────────────────────────────────────────
WORKDIR /demo
COPY demo.sh lxmf.py ./
RUN chmod +x demo.sh lxmf.py

# ── Shell environment ──────────────────────────────────────────────────────────
RUN printf '%s\n' \
    'export PS1="\[\033[0;36m\][reticulum]\[\033[0m\] \[\033[1m\]\w\[\033[0m\] \$ "' \
    'export TERM=xterm-256color' \
    'cd /demo' \
    >> /etc/bash.bashrc

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ttyd web terminal | Reticulum TCP interface (phones connect here)
EXPOSE 7681 4965

ENTRYPOINT ["/entrypoint.sh"]
