# support.misolves.com/codespace:0.0.5

# 1. Base Image: ubuntu-slim은 "ubuntu"의 경량 버전입니다.
FROM ubuntu:jammy-20251013

# 2. Update and Install OpenSSH Server AND Essential Tools (curl, tar, git, sudo)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y openssh-server curl tar wget git nano sudo \
    && mkdir -p /run/sshd \
    && chmod 0755 /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# 3. Create SSH User (abc)
RUN useradd -ms /bin/bash abc \
    && echo "abc:your_password" | chpasswd

# 3-1. Grant Sudo Privileges to 'abc' user**
RUN usermod -aG sudo abc

# --- code-server 설치 ---
# 4. Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# 5. Configure code-server for the 'abc' user
# code-server 설정을 위한 디렉토리 생성 및 권한 설정
RUN mkdir -p /home/abc/.config/code-server \
    && chown -R abc:abc /home/abc

# code-server 설정 파일 생성 (Password 설정만 남기고, bind-addr는 start.sh에서 강제 지정)
RUN echo "auth: password" > /home/abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /home/abc/.config/code-server/config.yaml \
    && chown abc:abc /home/abc/.config/code-server/config.yaml \
    && chmod 600 /home/abc/.config/code-server/config.yaml

# 6. Configure SSH (Existing)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- code-server/SSH 통합 및 포트 노출 ---

# 7. Expose SSH Port (22) and code-server Port (8080)
EXPOSE 22 8080

# 8. Entrypoint Script for Integrated Services
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 9. Run the Wrapper Script
CMD ["/usr/local/bin/start.sh"]