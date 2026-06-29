# ============================================================================
# cube-shell Linux Desktop Docker Image
#
# Build:
#   docker build -t hassis/cube-shell:latest .
#
# Run:
#   docker run -d \
#     --name cube-shell \
#     --restart=always \
#     -p 6080:6080 \
#     hassis/cube-shell:latest
#
# Access:
#   http://<host>:6080  (noVNC web interface)
#   注意：无 VNC 密码，仅限内网使用
# ============================================================================

FROM ubuntu:24.04

LABEL maintainer="hassis"
LABEL description="cube-shell Linux remote desktop with Web browser access (noVNC)"

ARG DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Install system packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    wget \
    curl \
    gnupg2 \
    ca-certificates \
    fonts-liberation \
    libasound2t64 \
    libxdamage1 \
    libnss3 \
    libxkbcommon0 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libxcomposite1 \
    libxfixes3 \
    libxrandr2 \
    libgl1 \
    xdg-utils \
    x11-utils \
    supervisor \
    dbus-x11 \
    python3 \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 1b. Install Firefox ESR via Mozilla PPA
# ---------------------------------------------------------------------------
RUN curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/packages.mozilla.org-archive.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/packages.mozilla.org-archive.gpg] \
    https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends firefox-esr && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Create non-root user
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash cubeuser && \
    echo "cubeuser:cube123" | chpasswd

# ---------------------------------------------------------------------------
# 3. Copy cube-shell binary and resources
# ---------------------------------------------------------------------------
COPY cube-shell.dist/ /home/cubeuser/cube-shell/

RUN chown -R cubeuser:cubeuser /home/cubeuser/cube-shell/ && \
    chmod +x /home/cubeuser/cube-shell/cube-shell.sh 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. Supervisord config
# ---------------------------------------------------------------------------
RUN mkdir -p /var/log/supervisor

COPY <<EOF /etc/supervisor/conf.d/cube-shell.conf
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
loglevel=info

[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 1920x1080x24
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/xvfb.log
stderr_logfile=/var/log/supervisor/xvfb.err.log

[program:xfce]
command=/bin/bash -c "for i in \$(seq 1 30); do xdpyinfo -display :99 >/dev/null 2>&1 && break || sleep 1; done; export DISPLAY=:99 && dbus-run-session -- /usr/bin/startxfce4"
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/xfce.log
stderr_logfile=/var/log/supervisor/xfce.err.log

[program:x11vnc]
# Wait for Xvfb to be ready, then start x11vnc
command=/bin/bash -c "for i in $(seq 1 30); do xdpyinfo -display :99 >/dev/null 2>&1 && break || sleep 1; done; /usr/bin/x11vnc -display :99 -rfbport 5900 -shared -forever -o /var/log/supervisor/x11vnc.log"
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc.err.log

[program:websockify]
command=/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5900
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/websockify.log
stderr_logfile=/var/log/supervisor/websockify.err.log
EOF

# ---------------------------------------------------------------------------
# 5. Entrypoint
# ---------------------------------------------------------------------------
COPY <<EOF /entrypoint.sh
#!/bin/bash
set -e
exec supervisord -c /etc/supervisor/conf.d/cube-shell.conf
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 6080

ENTRYPOINT ["/entrypoint.sh"]