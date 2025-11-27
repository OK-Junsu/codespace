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

# 1.3. Claude 설정 파일 복사
if [ ! -d "$ABC_HOME/.claude" ]; then
    echo "Claude config directory (.claude) not found. Copying from skeleton."
    cp -a "$SKEL_DIR/.claude" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.claude.json" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.claude.json.backup" "$ABC_HOME/"
fi

# 1.4. [핵심 수정] Claude 바이너리 및 엔진 복구
# 실제 claude 실행 파일이 있는지 확인합니다.
CLAUDE_REAL_BIN=$(find "$ABC_HOME/.local/share/claude" -name "claude" -type f 2>/dev/null | head -n 1)

if [ -z "$CLAUDE_REAL_BIN" ]; then
    echo "Claude binary missing or incomplete. Re-installing from skeleton..."
    
    # [중요] 불완전한 기존 디렉토리가 있다면 삭제하여 깨끗한 복사를 보장합니다.
    if [ -d "$ABC_HOME/.local" ]; then
        echo "Removing incomplete .local directory..."
        rm -rf "$ABC_HOME/.local"
    fi
    
    mkdir -p "$ABC_HOME/.local"
    # 스켈레톤에서 전체 복사
    echo "Copying fresh .local directory..."
    cp -a "$SKEL_DIR/.local/"* "$ABC_HOME/.local/"
else
    echo "Claude binary verification successful: $CLAUDE_REAL_BIN"
fi

# 1.5. 소유권 설정 (필수)
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D