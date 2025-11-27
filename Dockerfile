# support.misolves.com/codespace:0.0.2

# 1. Base Image: ubuntu-slim은 "ubuntu"의 경량 버전입니다.
FROM ubuntu:jammy-20251013

# 2. Update and Install OpenSSH Server
# DEBIAN_FRONTEND=noninteractive를 사용하여 설치 과정 중 사용자 입력 방지
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y openssh-server \
    # SSH 데몬이 필요한 디렉토리 수동 생성 및 권한 설정
    && mkdir -p /run/sshd \
    && chmod 0755 /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# 3. Create SSH User
# 'sshuser'라는 이름의 새 사용자 생성 및 비밀번호 설정 (실제 환경에서는 권장하지 않음, SSH Key 사용 권장)
# 여기서는 간단한 예시를 위해 비밀번호 기반 인증을 가정합니다.
# 사용자 홈 디렉토리 생성 및 셸 지정
RUN useradd -ms /bin/bash sshuser \
    && echo "sshuser:your_secure_password" | chpasswd

# 4. Configure SSH
# SSH 데몬이 root 계정으로 로그인하는 것을 방지하고, 비밀번호 인증을 허용하도록 설정
# 기본 설정은 /etc/ssh/sshd_config에 있습니다.
# PermitRootLogin: no로 설정 (보안 강화)
# PasswordAuthentication: yes로 설정 (테스트용)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 5. Expose SSH Port
EXPOSE 22

# 6. Run SSH Daemon
# 컨테이너 시작 시 sshd 데몬을 포그라운드로 실행
CMD ["/usr/sbin/sshd", "-D"]