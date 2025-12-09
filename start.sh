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

# --- 5. AUTOMATED GIT CLONE (NEW SECTION) ---

if [ -n "$GIT_REPO_URL" ]; then
    echo "Git repository URL detected."

    # 이미 프로젝트가 존재하는지 확인 (.git 폴더 유무)
    if [ -d "$WORKSPACE_DIR/.git" ]; then
        echo "Git repository already exists in workspace. Skipping clone."
    else
        # Workspace 폴더가 비어있지 않으면 clone이 실패할 수 있으므로 확인
        # (단, .sudo_as_admin_successful 같은 숨김 파일은 무시하거나, git clone시 . 사용 고려)
        
        echo "Cloning repository..."
        FINAL_REPO_URL="$GIT_REPO_URL"

        # HTTPS + Token 사용 시 URL 재조합
        # (https://github.com/user/repo.git -> https://user:token@github.com/user/repo.git)
        if [[ "$GIT_REPO_URL" == https://* ]] && [ -n "$GIT_TOKEN" ] && [ -n "$GIT_USERNAME" ]; then
            CLEAN_URL="${GIT_REPO_URL#https://}"
            FINAL_REPO_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${CLEAN_URL}"
            echo "Using HTTPS with Personal Access Token."
        fi

        # git clone 실행 (abc 권한으로, SSH Agent 환경변수 유지)
        # 주의: 디렉토리가 비어있어야 하므로 . 옵션 대신 디렉토리명을 지정하거나, 
        # 비어있는 $WORKSPACE_DIR에 clone 하도록 함.
        
        # 권한 확보를 위해 workspace 소유권 먼저 설정
        chown abc:abc "$WORKSPACE_DIR"
        
        # 클론 수행
        sudo -E -u abc git clone "$FINAL_REPO_URL" "$WORKSPACE_DIR"
        
        if [ $? -eq 0 ]; then
            echo "Git clone successful."
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