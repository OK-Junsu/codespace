#!/bin/bash
set -x

# --- 1. CONFIGURATION SETUP ---
ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Checking essential configurations..."

# 1.1. 쉘 초기화 파일 복사 (.profile에 PATH 설정이 포함됨)
if [ ! -f "$ABC_HOME/.profile" ]; then
    echo "Shell configuration not found. Copying from skeleton."
    cp -a "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.profile" "$ABC_HOME/"
fi

# 1.2. code-server 설정 복사
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "code-server config not found. Copying from skeleton."
    mkdir -p "$CODE_CONFIG_DIR"
    cp -a "$SKEL_DIR/.config/code-server/config.yaml" "$CODE_CONFIG_DIR/"
fi

# 1.3. (삭제됨) Claude 설정 파일 복사는 불필요하므로 제거했습니다.

# 1.4. 소유권 설정 (가장 중요)
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D