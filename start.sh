#!/bin/bash

# code-server를 백그라운드에서 실행 (user: abc)
echo "Starting code-server for user 'abc' on port 8080..."
# --disable-telemetry는 선택 사항입니다.
# -–user abc는 code-server를 'abc' 사용자로 실행하여 권한 문제를 방지합니다.
sudo -u abc /usr/bin/code-server --config /home/abc/.config/code-server/config.yaml &

# SSH 데몬을 포그라운드에서 실행
echo "Starting SSH Daemon on port 22..."
exec /usr/sbin/sshd -D