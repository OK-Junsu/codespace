# support.misolves.com/codespace:0.0.8

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
# '/usr/local/etc/skel_abc'는 바인드 마운트와 무관하게 이미지에 보존됩니다.
RUN mkdir -p /usr/local/etc/skel_abc/.config/code-server

# 7. Create code-server config file in STAGING
RUN echo "auth: password" > /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /usr/local/etc/skel_abc/.config/code-server/config.yaml

# 8. Copy essential shell configs to STAGING
# useradd 시 복사되는 기본 쉘 파일들을 Staging Directory에 복사합니다.
RUN cp /etc/skel/.bashrc /usr/local/etc/skel_abc/.bashrc \
    && cp /etc/skel/.profile /usr/local/etc/skel_abc/.profile

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