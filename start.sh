#!/bin/bash
set -x

# --- 0. ENVIRONMENT VARIABLES & DEFAULTS ---
USER_PASSWORD=${USER_PASSWORD:-"abc_password"}
WORKSPACE_DIR=${WORKSPACE_DIR:-"/home/abc/workspace"}
# GIT_REPO_URL, GIT_USERNAME, GIT_TOKEN are optional

ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Configuring container environment..."

# --- 1. BASE SETUP & PERMISSIONS ---

# 1.1. 사용자 암호 설정
echo "Setting user 'abc' password..."
echo "abc:$USER_PASSWORD" | chpasswd
touch "$ABC_HOME/.sudo_as_admin_successful"

# 1.2. Workspace 디렉토리 생성
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
fi

# 초기 권한 설정
chown abc:abc "$ABC_HOME"

# --- 2. RESTORE SKELETON FILES ---

# 2.1. 쉘 초기화 파일 복구
if [ ! -f "$ABC_HOME/.profile" ] || [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration missing. Copying from skeleton."
    cp -a "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.profile" "$ABC_HOME/"
    chown abc:abc "$ABC_HOME/.bashrc" "$ABC_HOME/.profile"
fi

# --- 3. GIT & SSH CONFIGURATION ---

# 3.1. Git Credential Helper 설정
if [ ! -f "$ABC_HOME/.gitconfig" ]; then
    echo "Initializing Git config..."
    sudo -u abc git config --global credential.helper store
fi

# 3.2. SSH Agent Socat Relay 설정
HOST_SOCKET="/ssh-agent"
NEW_SOCKET="/usr/local/etc/ssh-agent.sock"

if [ -S "$HOST_SOCKET" ]; then
    echo "SSH Agent socket found at $HOST_SOCKET"
    rm -f "$NEW_SOCKET"
    
    echo "Starting socat relay..."
    socat UNIX-LISTEN:$NEW_SOCKET,fork,group=abc,user=abc,mode=600 UNIX-CONNECT:$HOST_SOCKET &
    
    if ! grep -q "export SSH_AUTH_SOCK=$NEW_SOCKET" "$ABC_HOME/.bashrc"; then
        echo "" >> "$ABC_HOME/.bashrc"
        echo "# SSH Agent Relay" >> "$ABC_HOME/.bashrc"
        echo "export SSH_AUTH_SOCK=$NEW_SOCKET" >> "$ABC_HOME/.bashrc"
        echo "export SSH_AUTH_SOCK=$NEW_SOCKET" >> "$ABC_HOME/.profile"
    fi
    
    export SSH_AUTH_SOCK="$NEW_SOCKET"
else
    echo "WARNING: Host SSH Agent socket not found at $HOST_SOCKET"
fi

# --- 4. APP CONFIGURATION ---

# 4.1. Code-Server 설정
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

# 4.2. Claude 설정 복구
if [ ! -d "$ABC_HOME/.claude" ]; then
    cp -a "$SKEL_DIR/.claude" "$ABC_HOME/" 2>/dev/null || true
    cp -a "$SKEL_DIR/.claude.json" "$ABC_HOME/" 2>/dev/null || true
    cp -a "$SKEL_DIR/.claude.json.backup" "$ABC_HOME/" 2>/dev/null || true
fi

# 4.3. Claude 실행 환경 복구
CLAUDE_REAL_BIN=$(find "$ABC_HOME/.local/share/claude/versions" -type f 2>/dev/null | sort -V | tail -n 1)

if [ -z "$CLAUDE_REAL_BIN" ]; then
    echo "Claude binary missing. Re-installing from skeleton..."
    [ -d "$ABC_HOME/.local" ] && rm -rf "$ABC_HOME/.local"
    mkdir -p "$ABC_HOME/.local"
    cp -a "$SKEL_DIR/.local/"* "$ABC_HOME/.local/"
fi

# --- 5. AUTOMATED GIT CLONE (SUBDIRECTORY MODE) ---

if [ -n "$GIT_REPO_URL" ]; then
    echo "Git repository URL detected: $GIT_REPO_URL"

    # 1. URL에서 프로젝트 이름(디렉토리명) 추출
    # 예: ssh://.../codespace.git -> codespace
    REPO_NAME=$(basename "$GIT_REPO_URL" .git)
    TARGET_PROJECT_DIR="$WORKSPACE_DIR/$REPO_NAME"

    echo "Target project directory: $TARGET_PROJECT_DIR"

    # 2. 해당 프로젝트 폴더가 이미 존재하는지 확인
    if [ -d "$TARGET_PROJECT_DIR" ]; then
        echo "Project directory '$REPO_NAME' already exists in workspace. Skipping clone."
    else
        echo "Cloning repository into subdirectory '$REPO_NAME'..."
        
        FINAL_REPO_URL="$GIT_REPO_URL"

        # HTTPS + Token 사용 시 URL 재조합
        if [[ "$GIT_REPO_URL" == https://* ]] && [ -n "$GIT_TOKEN" ] && [ -n "$GIT_USERNAME" ]; then
            CLEAN_URL="${GIT_REPO_URL#https://}"
            FINAL_REPO_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${CLEAN_URL}"
            echo "Using HTTPS with Personal Access Token."
        fi

        # 3. Clone 실행
        # - 부모 디렉토리(Workspace) 권한 확인
        chown abc:abc "$WORKSPACE_DIR"
        
        # - Workspace로 이동 후 Clone 실행 (Git이 알아서 폴더 생성함)
        # - 호스트 키 검사 무시 옵션 포함
        cd "$WORKSPACE_DIR" || exit
        
        sudo -E -u abc env GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone "$FINAL_REPO_URL"
        
        if [ $? -eq 0 ]; then
            echo "Git clone successful: $TARGET_PROJECT_DIR"
        else
            echo "Git clone failed. Please check URL or credentials."
        fi
    fi
fi

# --- 6. FINAL SETUP ---

# 6.1. 초기 접속 위치 설정
if ! grep -q "cd $WORKSPACE_DIR" "$ABC_HOME/.bashrc"; then
    echo "" >> "$ABC_HOME/.bashrc"
    echo "# Initial working directory" >> "$ABC_HOME/.bashrc"
    echo "cd $WORKSPACE_DIR" >> "$ABC_HOME/.bashrc"
fi

# 6.2. 소유권 일괄 재설정
echo "Setting final ownership for $ABC_HOME..."
chown -R abc:abc "$ABC_HOME"
# Workspace는 용량이 클 수 있으므로 이미 권한이 맞다면 건너뛰는 것이 좋으나, 확실히 하기 위해 수행
chown -R abc:abc "$WORKSPACE_DIR"

# --- 7. START SERVICES ---

echo "Starting code-server..."
# HOME 변수 지정 필수
sudo -E -u abc HOME="$ABC_HOME" /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config "$CODE_CONFIG_DIR/config.yaml" "$WORKSPACE_DIR" &

echo "Starting SSH Daemon..."
exec /usr/sbin/sshd -D