# 1. Base Image
FROM ubuntu:jammy-20251013

# 2. Install necessary packages
ENV DEBIAN_FRONTEND=noninteractive

# [수정됨] Ubuntu 저장소를 Kakao Mirror로 변경하여 속도 향상 및 Hash Sum 오류 해결
RUN sed -i 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list \
    && sed -i 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y openssh-server curl tar wget git nano sudo socat tzdata \
    && mkdir -p /run/sshd \
    && chmod 0755 /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# 3. Create User 'abc'
# [수정] 초기 암호는 임시로 설정 (start.sh에서 변경됨)
RUN useradd -ms /bin/bash abc \
    && echo "abc:temporary_password" | chpasswd

# 4. Grant Sudo Privileges
RUN usermod -aG sudo abc

# 5. Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# 6. Create Staging Directory
RUN mkdir -p /usr/local/etc/skel_abc/.config/code-server \
    && mkdir -p /usr/local/etc/skel_abc/.local/bin \
    && mkdir -p /usr/local/etc/skel_abc/.local/share \
    # [추가] Workspace 디렉토리 생성
    && mkdir -p /usr/local/etc/skel_abc/workspace \
    && chown -R abc:abc /usr/local/etc/skel_abc

# 7. [수정] Code-server config creation REMOVED from Dockerfile
# (start.sh에서 환경 변수에 따라 동적으로 생성하기 위해 제거함)

# 8. Shell Configs & PATH Setup
RUN cp /etc/skel/.bashrc /usr/local/etc/skel_abc/.bashrc \
    && cp /etc/skel/.profile /usr/local/etc/skel_abc/.profile \
    && chown abc:abc /usr/local/etc/skel_abc/.bashrc \
    && chown abc:abc /usr/local/etc/skel_abc/.profile

RUN echo '' >> /usr/local/etc/skel_abc/.profile \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /usr/local/etc/skel_abc/.profile \
    && echo '' >> /usr/local/etc/skel_abc/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /usr/local/etc/skel_abc/.bashrc

# 9. Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 10. Install Claude Code & Setup (Wrapper Script Version)
RUN curl -fsSL https://claude.ai/install.sh | bash

RUN mkdir -p /usr/local/etc/skel_abc/.local/bin \
    && mkdir -p /usr/local/etc/skel_abc/.local/share

RUN mv /root/.local/share/claude /usr/local/etc/skel_abc/.local/share/claude \
    && chmod -R 755 /usr/local/etc/skel_abc/.local/share/claude

RUN echo '#!/bin/bash' > /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'REAL_BIN=$(find /home/abc/.local/share/claude/versions -type f | sort -V | tail -n 1)' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'if [ -z "$REAL_BIN" ]; then' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo '  echo "Error: No executable found in /home/abc/.local/share/claude/versions/"' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo '  exit 1' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'fi' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'exec "$REAL_BIN" "$@"' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && chmod 755 /usr/local/etc/skel_abc/.local/bin/claude

RUN ln -s /home/abc/.local/bin/claude /usr/local/bin/claude

RUN cp -r /root/.claude /usr/local/etc/skel_abc/ \
    && cp /root/.claude.json /usr/local/etc/skel_abc/ \
    && cp /root/.claude.json.backup /usr/local/etc/skel_abc/ \
    && chown -R abc:abc /usr/local/etc/skel_abc

# 11~13. Expose, Entrypoint
EXPOSE 22 8080
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
CMD ["/usr/local/bin/start.sh"]