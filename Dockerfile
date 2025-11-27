# support.misolves.com/codespace:0.0.16

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

# 8-1. Add PATH to BOTH .bashrc AND .profile
RUN echo '' >> /usr/local/etc/skel_abc/.profile \
    && echo 'export PATH="/usr/local/bin:$PATH"' >> /usr/local/etc/skel_abc/.profile \
    && echo '' >> /usr/local/etc/skel_abc/.bashrc \
    && echo 'export PATH="/usr/local/bin:$PATH"' >> /usr/local/etc/skel_abc/.bashrc

# 9. Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 10. Install Claude Code & Setup (핵심 변경 구간)
# 1) 설치 스크립트 실행
RUN curl -fsSL https://claude.ai/install.sh | bash

# 2) 바이너리 이동 및 권한 설정 (755로 설정하여 abc 실행 가능하게 함)
RUN mv /root/.local/bin/claude /usr/local/bin/claude \
    && chmod 755 /usr/local/bin/claude

# 3) [복원됨] 생성된 설정 파일들을 Staging으로 이동
# /root/.claude 등이 존재하는 것이 확인되었으므로 복사 진행
RUN cp -r /root/.claude /usr/local/etc/skel_abc/ \
    && cp /root/.claude.json /usr/local/etc/skel_abc/ \
    && cp /root/.claude.json.backup /usr/local/etc/skel_abc/ \
    && chown -R abc:abc /usr/local/etc/skel_abc

# 11. Expose Ports
EXPOSE 22 8080

# 12. Entrypoint Script
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 13. Run
CMD ["/usr/local/bin/start.sh"]