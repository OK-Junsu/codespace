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

# 1.4. [추가됨] Claude 바이너리 복사 (.local 디렉토리)
# 바인드 마운트 시 /home/abc/.local/bin/claude가 사라지므로 복사해야 합니다.
if [ ! -f "$ABC_HOME/.local/bin/claude" ]; then
    echo "Claude binary not found in home. Copying .local from skeleton."
    mkdir -p "$ABC_HOME/.local/bin"
    # -n: 기존 파일 덮어쓰지 않음 (선택 사항)
    cp -a "$SKEL_DIR/.local" "$ABC_HOME/"
fi

# 1.5. 소유권 설정 (필수)
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D