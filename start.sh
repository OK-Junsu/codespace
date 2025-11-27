#!/bin/bash

# --- 1. CONFIGURATION SETUP (Copy-on-Start Logic) ---
ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

echo "Checking essential configurations..."

# 1.1. 쉘 초기화 파일 복사: .bashrc 파일이 없으면 복사
if [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration (.bashrc, .profile) not found. Copying from skeleton."
    cp "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp "$SKEL_DIR/.profile" "$ABC_HOME/"
fi

# 1.2. code-server 설정 복사: config.yaml 파일이 없으면 복사
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "code-server config not found. Copying from skeleton."
    mkdir -p "$CODE_CONFIG_DIR"
    cp "$SKEL_DIR/.config/code-server/config.yaml" "$CODE_CONFIG_DIR/"
fi

# 1.3. 전체 홈 디렉토리 소유권 설정 (필수):
# 마운트된 볼륨은 종종 root 소유이므로, 'abc'가 사용하도록 소유권을 변경합니다.
# 이 단계는 설정 파일 복사 후에 반드시 이루어져야 합니다.
echo "Setting full ownership for $ABC_HOME to abc:abc"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

# code-server를 백그라운드에서 실행 (user: abc)
echo "Starting code-server for user 'abc' on port 8080..."
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

# SSH 데몬을 포그라운드에서 실행
echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D