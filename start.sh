#!/bin/bash
set -x

# --- 1. CONFIGURATION SETUP ---
ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Checking essential configurations..."

# 1.1. 쉘 초기화 파일 복사
if [ ! -f "$ABC_HOME/.profile" ] || [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration missing. Copying from skeleton."
    cp -a "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.profile" "$ABC_HOME/"
fi

# 1.2. code-server 설정 복사
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "code-server config not found. Copying from skeleton."
    mkdir -p "$CODE_CONFIG_DIR"
    cp -a "$SKEL_DIR/.config/code-server/config.yaml" "$CODE_CONFIG_DIR/"
fi

# 1.3. Claude 설정 파일 복사 (.claude 디렉토리 등)
if [ ! -d "$ABC_HOME/.claude" ]; then
    echo "Claude config directory (.claude) not found. Copying from skeleton."
    cp -a "$SKEL_DIR/.claude" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.claude.json" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.claude.json.backup" "$ABC_HOME/"
fi

# 1.4. Claude 실행 환경(.local) 전체 복사
# bin(런처)과 share(엔진)가 모두 .local 안에 있으므로 .local 전체를 복사하면 해결됨
if [ ! -d "$ABC_HOME/.local/share/claude" ]; then
    echo "Claude dependencies not found. Copying .local from skeleton."
    mkdir -p "$ABC_HOME/.local"
    # .local 디렉토리 내부를 병합하며 복사
    cp -a "$SKEL_DIR/.local/"* "$ABC_HOME/.local/"
fi

# 1.5. 소유권 설정 (필수)
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D