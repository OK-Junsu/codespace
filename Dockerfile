# support.misolves.com/codespace:0.0.3

# 1. Base Image: ubuntu-slim은 "ubuntu"의 경량 버전입니다.
FROM ubuntu:jammy-20251013

# 2. Update and Install OpenSSH Server AND Essential Tools (curl, tar, git, etc.)
# DEBIAN_FRONTEND=noninteractive를 사용하여 설치 과정 중 사용자 입력 방지
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y openssh-server curl tar wget git \
    # SSH 데몬이 필요한 디렉토리 수동 생성 및 권한 설정
    && mkdir -p /run/sshd \
    && chmod 0755 /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# --- code-server 설치 시작 ---

# 3. Install code-server
# code-server 공식 설치 스크립트 실행
# 이 스크립트는 code-server를 /usr/bin/code-server에 설치합니다.
RUN curl -fsSL https://code-server.dev/install.sh | sh

# 4. Create SSH User (abc) and code-server Configuration
# 'abc'라는 이름의 새 사용자 생성 및 비밀번호 설정
# 사용자 홈 디렉토리 생성 및 셸 지정
RUN useradd -ms /bin/bash abc \
    && echo "abc:your_password" | chpasswd

# 5. Configure code-server for the 'abc' user
# code-server 설정을 위한 디렉토리 생성
RUN mkdir -p /home/abc/.config/code-server \
    && chown -R abc:abc /home/abc

# code-server 설정 파일 생성 및 바인딩 주소 및 비밀번호 설정
# bind-addr: 0.0.0.0:8080으로 설정하여 외부 접속 허용
# password: your_password로 설정 (환경 변수 또는 비밀 파일 사용 권장)
RUN echo "bind-addr: 0.0.0.0:8080" > /home/abc/.config/code-server/config.yaml \
    && echo "auth: password" >> /home/abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /home/abc/.config/code-server/config.yaml \
    && chown abc:abc /home/abc/.config/code-server/config.yaml \
    && chmod 600 /home/abc/.config/code-server/config.yaml

# 6. Configure SSH (Existing)
# SSH 데몬이 root 계정으로 로그인하는 것을 방지하고, 비밀번호 인증을 허용하도록 설정
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- code-server/SSH 통합 및 포트 노출 ---

# 7. Expose SSH Port (22) and code-server Port (8080)
EXPOSE 22 8080

# 8. Entrypoint Script for Integrated Services
# code-server를 백그라운드에서 실행한 후 SSH 데몬을 포그라운드에서 실행
# 이 방법을 사용하면 컨테이너가 SSH 데몬을 통해 계속 실행됩니다.
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 9. Run the Wrapper Script
CMD ["/usr/local/bin/start.sh"]