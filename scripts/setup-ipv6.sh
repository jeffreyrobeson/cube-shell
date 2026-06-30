#!/bin/bash
# 确保 Docker 支持 IPv6（仅首次需运行）

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_JSON="${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"

if grep -q '"ipv6": true' "$DAEMON_JSON" 2>/dev/null; then
    echo "Docker IPv6 已配置，无需更改"
    exit 0
fi

echo "备份当前配置: cp $DAEMON_JSON $BACKUP_JSON"
cp "$DAEMON_JSON" "$BACKUP_JSON"

# 合并 IPv6 配置
python3 - << 'PYEOF'
import json, sys

with open("/etc/docker/daemon.json", "r") as f:
    config = json.load(f)

config["ipv6"] = True
config["fixed-cidr-v6"] = "fd00::/80"

with open("/etc/docker/daemon.json", "w") as f:
    json.dump(config, f, indent=2)

print("daemon.json 已更新")
PYEOF

systemctl restart docker
echo "Docker 已重启，现在可以用 --ipv6 启动容器了"
echo "或直接: docker run -d ... hassis/cube-shell:latest"