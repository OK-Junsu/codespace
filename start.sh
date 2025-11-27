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

# 1.4. [수정됨] Claude 바이너리 검증 및 복구
# 파일 이름이 'claude'가 아니어도(예: 2.0.55), versions 안에 파일이 있으면 설치된 것으로 간주
CLAUDE_REAL_BIN=$(find "$ABC_HOME/.local/share/claude/versions" -type f 2>/dev/null | sort -V | tail -n 1)

if [ -z "$CLAUDE_REAL_BIN" ]; then
    echo "Claude binary missing or incomplete. Re-installing from skeleton..."
    
    if [ -d "$ABC_HOME/.local" ]; then
        echo "Removing incomplete .local directory..."
        rm -rf "$ABC_HOME/.local"
    fi
    
    mkdir -p "$ABC_HOME/.local"
    echo "Copying fresh .local directory..."
    cp -a "$SKEL_DIR/.local/"* "$ABC_HOME/.local/"
else
    echo "Claude binary verification successful: $CLAUDE_REAL_BIN"
fi

# 1.5. 소유권 설정
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D