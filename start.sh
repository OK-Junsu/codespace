#!/bin/bash
set -x

# --- 0. ENVIRONMENT VARIABLES & DEFAULTS ---
USER_PASSWORD=${USER_PASSWORD:-"abc_password"}
WORKSPACE_DIR=${WORKSPACE_DIR:-"/home/abc/workspace"}
# SSH_AUTH_SOCK은 docker-compose에서 주입됨

ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Configuring container environment..."

# --- 1. USER CONFIGURATION ---

# 1.1. 사용자 암호 설정
echo "Setting user 'abc' password..."
echo "abc:$USER_PASSWORD" | chpasswd

# 1.2. Workspace 디렉토리 생성
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
fi

# --- 2. GIT & SSH CONFIGURATION (2단계 추가) ---

# 2.1. Git Credential Helper 설정
# .gitconfig 파일이 없으면 생성하고 store 모드로 설정
if [ ! -f "$ABC_HOME/.gitconfig" ]; then
    echo "Initializing Git config..."
    # sudo -u abc를 사용하여 abc 권한으로 파일 생성
    sudo -u abc git config --global credential.helper store
    echo "Git credential helper set to 'store'."
fi

# 2.2. SSH Agent 권한 우회 (소켓 파일 접근 권한)
# 호스트에서 마운트된 소켓은 권한 문제로 abc가 못 읽을 수 있습니다.
# 소켓이 존재하면, ACL이나 권한을 조정하는 것이 정석이나, 
# 컨테이너 내부이므로 간단히 소켓의 그룹 권한을 수정하거나 확인만 합니다.
if [ -S "$SSH_AUTH_SOCK" ]; then
    echo "SSH Agent socket found at $SSH_AUTH_SOCK"
    # 소켓 파일 권한 완화 (abc가 읽고 쓸 수 있도록)
    chmod 777 "$SSH_AUTH_SOCK" || true
fi


# --- 3. RESTORE SKELETON FILES (기존 로직) ---

# 3.1. 쉘 초기화 파일 복사
if [ ! -f "$ABC_HOME/.profile" ] || [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration missing. Copying from skeleton."
    cp -a "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.profile" "$ABC_HOME/"
fi

# 3.2. Code-Server 설정 파일 동적 생성
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "Generating code-server config..."
    mkdir -p "$CODE_CONFIG_DIR"
    
    if [ -z "$CS_PASSWORD" ]; then
        AUTH_METHOD="none"
        PASSWORD_LINE=""
    else
        AUTH_METHOD="password"
        PASSWORD_LINE="password: $CS_PASSWORD"
    fi

    cat > "$CODE_CONFIG_DIR/config.yaml" <<EOF
bind-addr: 0.0.0.0:8080
auth: $AUTH_METHOD
$PASSWORD_LINE
cert: false
EOF
fi

# 3.3. Claude 관련 파일 복구
if [ ! -d "$ABC_HOME/.claude" ]; then
    cp -a "$SKEL_DIR/.claude" "$ABC_HOME/" 2>/dev/null || true
    cp -a "$SKEL_DIR/.claude.json" "$ABC_HOME/" 2>/dev/null || true
fi

CLAUDE_REAL_BIN=$(find "$ABC_HOME/.local/share/claude/versions" -type f 2>/dev/null | sort -V | tail -n 1)
if [ -z "$CLAUDE_REAL_BIN" ]; then
    echo "Claude binary missing. Re-installing from skeleton..."
    [ -d "$ABC_HOME/.local" ] && rm -rf "$ABC_HOME/.local"
    mkdir -p "$ABC_HOME/.local"
    cp -a "$SKEL_DIR/.local/"* "$ABC_HOME/.local/"
fi

# --- 4. FINAL SETUP ---

# 4.1. 초기 접속 위치 설정
if ! grep -q "cd $WORKSPACE_DIR" "$ABC_HOME/.bashrc"; then
    echo "" >> "$ABC_HOME/.bashrc"
    echo "# Initial working directory" >> "$ABC_HOME/.bashrc"
    echo "cd $WORKSPACE_DIR" >> "$ABC_HOME/.bashrc"
fi

# 4.2. 소유권 일괄 설정
echo "Setting ownership for $ABC_HOME..."
chown -R abc:abc "$ABC_HOME"
chown -R abc:abc "$WORKSPACE_DIR"

# --- 5. START SERVICES ---

echo "Starting code-server..."
# [중요] SSH_AUTH_SOCK 환경 변수를 명시적으로 전달해야 합니다.
sudo -u abc SSH_AUTH_SOCK="$SSH_AUTH_SOCK" /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config "$CODE_CONFIG_DIR/config.yaml" "$WORKSPACE_DIR" &

echo "Starting SSH Daemon..."
exec /usr/sbin/sshd -D