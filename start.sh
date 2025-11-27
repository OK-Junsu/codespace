#!/bin/bash

# --- 1. CONFIGURATION SETUP (Copy-on-Start Logic) ---
# 바인드 마운트 사용 시 유실되는 필수 설정 파일을 복원합니다.

ABC_HOME="/home/abc"
SKEL_DIR="/usr/local/etc/skel_abc"
CODE_CONFIG_DIR="$ABC_HOME/.config/code-server"

# 1.1. code-server 설정 복사: config.yaml 파일이 없으면 복사
# (마운트로 인해 config 디렉토리가 사라졌을 경우)
if [ ! -f "$CODE_CONFIG_DIR/config.yaml" ]; then
    echo "code-server config not found. Copying from skeleton."
    mkdir -p "$CODE_CONFIG_DIR"
    cp "$SKEL_DIR/.config/code-server/config.yaml" "$CODE_CONFIG_DIR/"
fi

# 1.2. 쉘 초기화 파일 복사: .bashrc 파일이 없으면 복사
# (마운트로 인해 쉘 환경 설정이 사라졌을 경우)
if [ ! -f "$ABC_HOME/.bashrc" ]; then
    echo "Shell configuration (.bashrc, .profile) not found. Copying from skeleton."
    cp "$SKEL_DIR/.bashrc" "$ABC_HOME/"
    cp "$SKEL_DIR/.profile" "$ABC_HOME/"
fi

# 1.3. 파일 소유권 설정 (필수):
# 마운트된 볼륨의 소유권은 종종 root로 설정되므로, 'abc'가 사용하도록 소유권을 변경합니다.
echo "Setting file ownership to abc:abc for $ABC_HOME"
chown -R abc:abc "$ABC_HOME"

# --- 2. START SERVICES ---

# code-server를 백그라운드에서 실행 (user: abc)
echo "Starting code-server for user 'abc' on port 8080..."
# -u abc가 설정 파일을 읽을 수 있도록 소유권 설정 후에 실행합니다.
sudo -u abc /usr/bin/code-server --bind-addr 0.0.0.0:8080 --config /home/abc/.config/code-server/config.yaml &

# SSH 데몬을 포그라운드에서 실행
echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D