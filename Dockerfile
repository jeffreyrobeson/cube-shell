# ============================================================================
# cube-shell Linux Desktop Docker Image
#
# Build:
#   docker build -t hassis/cube-shell:latest .
#
# Run (默认密码):
#   docker run -d \
#     --name cube-shell \
#     --restart=always \
#     -p 6080:6080 \
#     hassis/cube-shell:latest
#
# Run (自定义密码):
#   docker run -d \
#     --name cube-shell \
#     --restart=always \
#     -p 6080:6080 \
#     -e VNC_PASSWORD=*** \
#     hassis/cube-shell:latest
#
# Access:
#   http://<host>:6080  (noVNC web interface)
# ============================================================================

FROM ubuntu:24.04

LABEL maintainer="hassis"
LABEL description="cube-shell Linux remote desktop with Web browser access (noVNC)"

# Runtime VNC password (默认 CubeShell123，可通过 -e VNC_PASSWORD=xxx 覆盖)
ENV VNC_PASSWORD=CubeShell123
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
    python3 \
    python3-pip \
    supervisor \
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
# 4. Prepare VNC dirs (password file generated at runtime)
# ---------------------------------------------------------------------------
RUN mkdir -p /home/cubeuser/.vnc /var/log/supervisor

# ---------------------------------------------------------------------------
# 5. Supervisord config
# ---------------------------------------------------------------------------
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
command=/usr/bin/startxfce4
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/xfce.log
stderr_logfile=/var/log/supervisor/xfce.err.log

[program:x11vnc]
command=/usr/bin/x11vnc -display :99 -rfbport 5900 -rfbauth /home/cubeuser/.vnc/passwd -shared -forever -bg -o /var/log/supervisor/x11vnc.log
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
# 6. Entrypoint (运行时生成 VNC 密码文件)
# ---------------------------------------------------------------------------
COPY <<EOF /entrypoint.sh
#!/bin/bash
set -e

# 运行时生成 VNC 密码文件（支持 docker run -e VNC_PASSWORD=xxx）
# 运行时生成 VNC 密码文件（支持 docker run -e VNC_PASSWORD=*** 传参）
mkdir -p /home/cubeuser/.vnc
printf '%s\n' "${VNC_PASSWORD}" "${VNC_PASSWORD}" | x11vnc -storepasswd
mv /home/cubeuser/.vnc/passwd /home/cubeuser/.vnc/passwd.bak 2>/dev/null || true
x11vnc -storepasswd "${VNC_PASSWORD}" /home/cubeuser/.vnc/passwd
chown -R cubeuser:cubeuser /home/cubeuser/.vnc/
chmod 600 /home/cubeuser/.vnc/passwd

exec supervisord -c /etc/supervisor/conf.d/cube-shell.conf
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 6080

ENTRYPOINT ["/entrypoint.sh"]