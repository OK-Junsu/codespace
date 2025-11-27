# support.misolves.com/codespace:0.0.6

# 1. Base Image: ubuntu-slim은 "ubuntu"의 경량 버전입니다.
FROM ubuntu:jammy-20251013

# 2. Set Environment Variables
ENV DEBIAN_FRONTEND=noninteractive

# 3. Install necessary packages
RUN apt-get update \
    && apt-get install -y openssh-server curl tar wget git nano sudo \
    && mkdir -p /run/sshd \
    && chmod 0755 /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# 4. Create SSH User (abc)
RUN useradd -ms /bin/bash abc \
    && echo "abc:your_password" | chpasswd

# 5. Grant Sudo Privileges to 'abc' user**
RUN usermod -aG sudo abc

# --- code-server 설치 ---

# 6. Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# 7. Configure code-server for the 'abc' user
# code-server 설정을 위한 디렉토리 생성 및 권한 설정
RUN mkdir -p /home/abc/.config/code-server \
    && chown -R abc:abc /home/abc

# 8. code-server 설정 파일 생성 (Password 설정만 남기고, bind-addr는 start.sh에서 강제 지정)
RUN echo "auth: password" > /home/abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /home/abc/.config/code-server/config.yaml \
    && chown abc:abc /home/abc/.config/code-server/config.yaml \
    && chmod 600 /home/abc/.config/code-server/config.yaml

# 9. Configure SSH (Existing)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- Claude Code 설치 ---

# 10. Install Claude Code for the 'abc' user
# RUN user abc로 전환하여 Claude를 설치하고, 설치 경로를 사용자 홈 디렉토리(~/.local/bin)로 지정합니다.
USER abc
RUN curl -fsSL https://claude.ai/install.sh | bash
# 다시 root로 전환하여 다음 RUN 명령어를 실행하거나, 필요한 파일 권한을 설정합니다.
USER root

# 11. Set PATH for Claude Code in .bashrc
# Claude 설치 스크립트가 일반적으로 $HOME/.local/bin에 파일을 넣으므로,
# abc 사용자의 홈 디렉토리(/home/abc)의 .bashrc 파일에 PATH를 추가합니다.
RUN echo 'export PATH="/home/abc/.local/bin:$PATH"' >> /home/abc/.bashrc \
    && chown abc:abc /home/abc/.bashrc

# --- code-server/SSH 통합 및 포트 노출 ---

# 12. Expose SSH Port (22) and code-server Port (8080)
EXPOSE 22 8080 8443

# 13. Entrypoint Script for Integrated Services
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 14. Run the Wrapper Script
CMD ["/usr/local/bin/start.sh"]