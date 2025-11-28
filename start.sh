#!/bin/bash
set -x

# --- 0. ENVIRONMENT VARIABLES & DEFAULTS ---
# 환경 변수가 없으면 기본값을 사용합니다.
USER_PASSWORD=${USER_PASSWORD:-"abc_password"}
WORKSPACE_DIR=${WORKSPACE_DIR:-"/home/abc/workspace"}
# CS_PASSWORD가 비어있으면 "none" (암호 없음)으로 처리할 로직을 아래에서 수행

ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Configuring container environment..."

# --- 1. USER CONFIGURATION ---

# 1.1. 사용자 암호 설정 (호스트 ssh 접속용)
echo "Setting user 'abc' password..."
echo "abc:$USER_PASSWORD" | chpasswd

# 1.2. Workspace 디렉토리 생성 및 권한 설정
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
fi
# 워크스페이스 소유권은 나중에 일괄 처리

# --- 2. RESTORE SKELETON FILES ---

# 2.1. 쉘 초기화 파일 복사
if [ ! -f "$ABC_HOME/.profile" ] || [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration missing. Copying from skeleton."
    cp -a "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.profile" "$ABC_HOME/"
fi

# 2.2. [수정됨] Code-Server 설정 파일 동적 생성
# 기존 파일을 복사하는 대신, 환경 변수에 따라 새로 작성합니다.
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "Generating code-server config..."
    mkdir -p "$CODE_CONFIG_DIR"
    
    if [ -z "$CS_PASSWORD" ]; then
        # 암호가 없으면 인증 없음
        AUTH_METHOD="none"
        PASSWORD_LINE=""
        echo "Code-Server authentication: DISABLED"
    else
        # 암호가 있으면 설정
        AUTH_METHOD="password"
        PASSWORD_LINE="password: $CS_PASSWORD"
        echo "Code-Server authentication: PASSWORD SET"
    fi

    # config.yaml 파일 작성
    cat > "$CODE_CONFIG_DIR/config.yaml" <<EOF
bind-addr: 0.0.0.0:8080
auth: $AUTH_METHOD
$PASSWORD_LINE
cert: false
EOF
fi

# 2.3. Claude 관련 파일 복구 (이전 로직 유지)
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

# --- 3. FINAL SETUP ---

# 3.1. [추가] 초기 접속 위치 설정 (SSH용)
# .bashrc 끝에 cd 명령어가 없으면 추가합니다.
if ! grep -q "cd $WORKSPACE_DIR" "$ABC_HOME/.bashrc"; then
    echo "" >> "$ABC_HOME/.bashrc"
    echo "# Initial working directory" >> "$ABC_HOME/.bashrc"
    echo "cd $WORKSPACE_DIR" >> "$ABC_HOME/.bashrc"
fi

# 3.2. 소유권 일괄 설정
echo "Setting ownership for $ABC_HOME..."
chown -R abc:abc "$ABC_HOME"
# Workspace가 홈 외부에 있을 경우를 대비해 별도 권한 설정
chown -R abc:abc "$WORKSPACE_DIR"

# --- 4. START SERVICES ---

echo "Starting code-server..."
# [수정] 실행 인자에 WORKSPACE_DIR을 추가하여 해당 폴더를 엽니다.
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config "$CODE_CONFIG_DIR/config.yaml" "$WORKSPACE_DIR" &

echo "Starting SSH Daemon..."
exec /usr/sbin/sshd -D