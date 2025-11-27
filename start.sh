#!/bin/bash
# 모든 명령을 실행 전에 출력하여 디버깅합니다. (스크립트 실행 후 제거 권장)
set -x

# --- 1. CONFIGURATION SETUP (Copy-on-Start Logic) ---
ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Checking essential configurations..."

# 1.1. 쉘 초기화 파일 복사: .bashrc 파일이 없으면 복사
if [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration (.bashrc, .profile) not found. Attempting copy from skeleton."
    # cp -a (Archive) 모드로 복사하여 심볼릭 링크 및 속성을 유지하고, 디렉토리를 통째로 복사합니다.
    cp -a "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp -a "$SKEL_DIR/.profile" "$ABC_HOME/"

    # 복사 성공 여부 확인 (디버깅용)
    if [ -f "$ABC_HOME/.bashrc" ]; then
        echo "SUCCESS: .bashrc copied."
    else
        echo "FAILURE: .bashrc NOT copied. Check permissions or staging path ($SKEL_DIR)."
    fi
fi

# 1.2. code-server 설정 복사: config.yaml 파일이 없으면 복사
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "code-server config not found. Attempting copy from skeleton."
    mkdir -p "$CODE_CONFIG_DIR"
    cp -a "$SKEL_DIR/.config/code-server/config.yaml" "$CODE_CONFIG_DIR/"

    # 복사 성공 여부 확인 (디버깅용)
    if [ -f "$CODE_CONFIG_DIR/config.yaml" ]; then
        echo "SUCCESS: code-server config copied."
    else
        echo "FAILURE: code-server config NOT copied. Check permissions or staging path ($SKEL_DIR)."
    fi
fi

# 1.3. 전체 홈 디렉토리 소유권 설정 (필수):
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

# code-server를 백그라운드에서 실행 (user: abc)
echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

# SSH 데몬을 포그라운드에서 실행
echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D