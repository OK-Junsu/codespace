# support.misolves.com/codespace:0.0.11

# 1. Base Image
FROM ubuntu:jammy-20251013

# 2. Install necessary packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y openssh-server curl tar wget git nano sudo \
    && mkdir -p /run/sshd \
    && chmod 0755 /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# 3. Create User 'abc'
RUN useradd -ms /bin/bash abc \
    && echo "abc:your_password" | chpasswd

# 4. Grant Sudo Privileges to 'abc' user
RUN usermod -aG sudo abc

# 5. Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# --- 설정 파일 스테이징 (Staging) ---
# 마운트의 영향을 받지 않는 안전한 경로에 필수 설정 파일을 복사합니다.

# 6. Create Staging Directory
RUN mkdir -p /usr/local/etc/skel_abc/.config/code-server \
    # Staging 디렉토리가 abc 사용자의 설정을 담고 있음을 명시하기 위해 권한 설정
    && chown -R abc:abc /usr/local/etc/skel_abc

# 7. Create code-server config file in STAGING
# 주의: 이 파일은 root가 생성하므로, 나중에 start.sh에서 복사할 때 소유권 처리가 필수임.
RUN echo "auth: password" > /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    # 스테이징 파일 자체의 소유권을 abc로 설정
    && chown abc:abc /usr/local/etc/skel_abc/.config/code-server/config.yaml

# 8. Copy essential shell configs to STAGING
# /etc/skel 파일도 root 소유이므로, 복사 후 소유권을 abc로 변경합니다.
RUN cp /etc/skel/.bashrc /usr/local/etc/skel_abc/.bashrc \
    && cp /etc/skel/.profile /usr/local/etc/skel_abc/.profile \
    && chown abc:abc /usr/local/etc/skel_abc/.bashrc \
    && chown abc:abc /usr/local/etc/skel_abc/.profile

# --- 기존 SSH/Claude 설정 ---

# 9. Configure SSH (Existing)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 10. Install Claude Code and move to System PATH
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && mv /root/.local/bin/claude /usr/local/bin/claude \
    && chmod +x /usr/local/bin/claude

# 11. Expose SSH Port (22) and code-server Port (8080)
EXPOSE 22 8080

# 12. Entrypoint Script for Integrated Services (start.sh copy)
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 13. Run the Wrapper Script
CMD ["/usr/local/bin/start.sh"]