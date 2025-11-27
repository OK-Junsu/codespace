# support.misolves.com/codespace:0.0.15

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

# 6. Create Staging Directory
RUN mkdir -p /usr/local/etc/skel_abc/.config/code-server \
    && chown -R abc:abc /usr/local/etc/skel_abc

# 7. Create code-server config file in STAGING
RUN echo "auth: password" > /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    && chown abc:abc /usr/local/etc/skel_abc/.config/code-server/config.yaml

# 8. Copy essential shell configs to STAGING
RUN cp /etc/skel/.bashrc /usr/local/etc/skel_abc/.bashrc \
    && cp /etc/skel/.profile /usr/local/etc/skel_abc/.profile \
    && chown abc:abc /usr/local/etc/skel_abc/.bashrc \
    && chown abc:abc /usr/local/etc/skel_abc/.profile

# [수정됨] 8-1. Add PATH to .bashrc AND .profile
# SSH 접속(.profile)과 code-server 터미널(.bashrc) 모두를 위해 두 파일에 설정을 추가합니다.
RUN echo '' >> /usr/local/etc/skel_abc/.profile \
    && echo 'export PATH="/usr/local/bin:$PATH"' >> /usr/local/etc/skel_abc/.profile \
    && echo '' >> /usr/local/etc/skel_abc/.bashrc \
    && echo '# Add /usr/local/bin to PATH for Claude' >> /usr/local/etc/skel_abc/.bashrc \
    && echo 'export PATH="/usr/local/bin:$PATH"' >> /usr/local/etc/skel_abc/.bashrc

# 9. Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 10. Install Claude Code & Move Binary (권한 수정 핵심 단계)
# chmod 755를 사용하여 abc 사용자도 읽고 실행할 수 있도록 설정합니다.
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && mv /root/.local/bin/claude /usr/local/bin/claude \
    && chmod 755 /usr/local/bin/claude

# 11. Expose Ports
EXPOSE 22 8080

# 12. Entrypoint Script
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 13. Run
CMD ["/usr/local/bin/start.sh"]