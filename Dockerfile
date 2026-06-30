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

# ------------------------------------------------------------------
# 1. Install system packages
# ------------------------------------------------------------------
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
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
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
    libegl1 \
    xdg-utils \
    x11-utils \
    supervisor \
    bzip2 \
    xz-utils \
    dbus-x11 \
    python3-full \
    python3-venv \
    python3-dev \
    libffi-dev \
    libssl-dev \
    libxcb-cursor0 \
    libxkbcommon-x11-0 \
    libgl1 \
    libegl1 \
    libasound2t64 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 1a. Install missing XCB libraries (not in Ubuntu 24.04 repos)
# ------------------------------------------------------------------
RUN wget -q https://launchpadlibrarian.net/401200993/libxcb-icccm4_0.4.1-1.1_amd64.deb -O /tmp/icccm.deb && \
    wget -q https://launchpadlibrarian.net/188249133/libxcb-keysyms1_0.4.0-1_amd64.deb -O /tmp/keysyms.deb && \
    dpkg -i /tmp/icccm.deb || true && \
    dpkg -i --ignore-depends=libxcb-keysyms1 /tmp/keysyms.deb || true && \
    ldconfig && \
    rm -f /tmp/icccm.deb /tmp/keysyms.deb

# ------------------------------------------------------------------
# 1b. Install Firefox ESR via Mozilla archive
# ------------------------------------------------------------------
RUN curl -sL https://ftp.mozilla.org/pub/firefox/releases/152.0.3/linux-x86_64/en-US/firefox-152.0.3.tar.xz -o /tmp/firefox.tar.xz&& \
    tar -xJf /tmp/firefox.tar.xz -C /opt && \
    mv /opt/firefox /opt/firefox-esr && \
    ln -sf /opt/firefox-esr/firefox /usr/local/bin/firefox && \
    rm -f /tmp/firefox.tar.xz && \
    mkdir -p /usr/share/applications && \
    echo '[Desktop Entry]\nVersion=1.0\nName=Firefox\nComment=Web Browser\nExec=env LIBGL_ALWAYS_INDIRECT=1 MOZ_WEBRENDER=0 /opt/firefox-esr/firefox %u\nIcon=/opt/firefox-esr/browser/chrome/icons/default/default128.png\nTerminal=false\nType=Application\nCategories=Network;WebBrowser;\nMimeType=text/html;application/xhtml+xml;text/plain;' > /usr/share/applications/firefox-esr.desktop

# ------------------------------------------------------------------
# 2. Create non-root user
# ------------------------------------------------------------------
RUN useradd -m -s /bin/bash cubeuser && \
    echo "cubeuser:cube123" | chpasswd && \
    mkdir -p /home/cubeuser/.config/xfce4 && \
    echo 'WebBrowser=firefox-esr' > /home/cubeuser/.config/xfce4/helpers.rc && \
    chown -R cubeuser:cubeuser /home/cubeuser/.config


# ------------------------------------------------------------------
# 3. Create venv and install Python dependencies
# ------------------------------------------------------------------
RUN python3 -m venv /opt/venv

COPY requirements.txt /tmp/requirements.txt
# Install Python deps in two steps (aardwolf needs Rust, handle separately)
RUN /opt/venv/bin/pip install --upgrade pip wheel setuptools && \
    /opt/venv/bin/pip install \
    PySide6==6.11.1 \
    'paramiko>=5.0.0' \
    'Pygments>=2.20.0' \
    'deepdiff>=9.1.0' \
    'pyqtdarktheme-fork>=2.3.6' \
    'toml>=0.10.2' \
    'appdirs>=1.4.4' \
    'PyYAML>=6.0.3' \
    'openai>=2.37.0' \
    'keyring>=25.7.0' \
    'prompt_toolkit>=3.0.52'
RUN /opt/venv/bin/pip install 'Pillow>=11.0.0' 'requests>=2.34.0' 'pyperclip>=1.9.0'
RUN /opt/venv/bin/pip install 'aardwolf>=0.2.13' --only-binary=:all:; \
    /opt/venv/bin/pip install qtermwidget 2>/dev/null; \
    true

# ------------------------------------------------------------------
# 4. Copy cube-shell source code (not binary)
# ------------------------------------------------------------------
# Copy entire project (skip missing with RUN, don't fail build)
COPY . /home/cubeuser-build/

RUN mv /home/cubeuser-build/cube-shell.py /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/conf /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/core /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/function /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/style /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/ui /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/icons /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/qtermwidget /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/i18n /home/cubeuser/ 2>/dev/null || true && \
    mv /home/cubeuser-build/tools /home/cubeuser/ 2>/dev/null || true && \
    rm -rf /home/cubeuser-build && \
    true

RUN chown -R cubeuser:cubeuser /home/cubeuser/

# ------------------------------------------------------------------
# 5. Supervisord config
# ------------------------------------------------------------------
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
command=/bin/bash -c "for i in \$(seq 1 30); do xdpyinfo -display :99 >/dev/null 2>&1 && break || sleep 1; done; export DISPLAY=:99 && /usr/bin/xfce4-session"
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/xfce.log
stderr_logfile=/var/log/supervisor/xfce.err.log

[program:x11vnc]
command=/usr/bin/x11vnc -rfbauth /root/.vnc/passwd
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc.err.log

[program:cube-shell]
command=/bin/bash -c "for i in \$(seq 1 60); do pgrep xfce4-session > /dev/null && break || sleep 1; done; export DISPLAY=:99 && export QT_QPA_PLATFORM=xcb && export QT_QPA_PLATFORM_PLUGIN_PATH=/opt/venv/lib/python3.12/site-packages/PySide6/Qt/plugins && exec /opt/venv/bin/python3 /home/cubeuser/cube-shell.py"
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/cube-shell.log
stderr_logfile=/var/log/supervisor/cube-shell.err.log

[program:websockify]
command=/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5900
user=root
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/websockify.log
stderr_logfile=/var/log/supervisor/websockify.err.log
EOF

# ------------------------------------------------------------------
# 6. Entrypoint
# ------------------------------------------------------------------
COPY <<EOF /entrypoint.sh
#!/bin/bash
set -e
exec supervisord -c /etc/supervisor/conf.d/cube-shell.conf
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 6080

ENTRYPOINT ["/entrypoint.sh"]