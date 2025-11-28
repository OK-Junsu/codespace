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

# 2.2. [완전 교체] SSH Agent Socat Relay 설정
# 호스트(Root) Agent와 컨테이너(abc) 간의 UID 불일치 문제를 해결하기 위해 socat으로 중계합니다.

# 호스트에서 마운트된 원본 소켓
HOST_SOCKET="/ssh-agent"
# abc 사용자가 실제로 사용할 중계 소켓 경로
NEW_SOCKET="/usr/local/etc/ssh-agent.sock"

if [ -S "$HOST_SOCKET" ]; then
    echo "SSH Agent socket found at $HOST_SOCKET"
    
    # 기존에 남아있을 수 있는 중계 소켓 삭제
    rm -f "$NEW_SOCKET"

    # [핵심] socat 실행 (백그라운드)
    # Root 권한으로 실행되어 호스트 소켓(UID 0)과 통신하고,
    # 생성된 소켓($NEW_SOCKET)은 abc 사용자가 접근 가능하도록 권한(user=abc)을 설정합니다.
    echo "Starting socat relay..."
    socat UNIX-LISTEN:$NEW_SOCKET,fork,group=abc,user=abc,mode=600 UNIX-CONNECT:$HOST_SOCKET &
    
    # 쉘 설정에 새로운 소켓 경로 등록
    if ! grep -q "export SSH_AUTH_SOCK=$NEW_SOCKET" "$ABC_HOME/.bashrc"; then
        echo "" >> "$ABC_HOME/.bashrc"
        echo "# SSH Agent Relay" >> "$ABC_HOME/.bashrc"
        echo "export SSH_AUTH_SOCK=$NEW_SOCKET" >> "$ABC_HOME/.bashrc"
        
        echo "export SSH_AUTH_SOCK=$NEW_SOCKET" >> "$ABC_HOME/.profile"
    fi
    
    # 현재 스크립트 실행 환경(code-server 실행용)에도 변수 적용
    export SSH_AUTH_SOCK="$NEW_SOCKET"
    echo "SSH Agent relay established at $NEW_SOCKET"
else
    echo "WARNING: Host SSH Agent socket not found at $HOST_SOCKET"
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