# support.misolves.com/codespace:0.0.22

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
    && mkdir -p /usr/local/etc/skel_abc/.local/bin \
    && mkdir -p /usr/local/etc/skel_abc/.local/share \
    && chown -R abc:abc /usr/local/etc/skel_abc

# 7. Create code-server config file
RUN echo "auth: password" > /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /usr/local/etc/skel_abc/.config/code-server/config.yaml \
    && chown abc:abc /usr/local/etc/skel_abc/.config/code-server/config.yaml

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

# 10. Install Claude Code & Setup (Filename agnostic wrapper)
# 1) 설치 스크립트 실행
RUN curl -fsSL https://claude.ai/install.sh | bash

# 2) 디렉토리 구조 생성
RUN mkdir -p /usr/local/etc/skel_abc/.local/bin \
    && mkdir -p /usr/local/etc/skel_abc/.local/share

# 3) 엔진(share) 이동 및 권한 설정
RUN mv /root/.local/share/claude /usr/local/etc/skel_abc/.local/share/claude \
    && chmod -R 755 /usr/local/etc/skel_abc/.local/share/claude

# 4) [수정됨] 래퍼 스크립트 생성 (이름 무관하게 실행 파일 찾기)
# versions 폴더 안의 파일 이름이 버전(예: 2.0.55)이어도 찾을 수 있도록 수정
# ls -t (시간순 정렬) 또는 sort -V (버전순 정렬)을 사용하여 가장 최신 파일을 선택
RUN echo '#!/bin/bash' > /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'REAL_BIN=$(find /home/abc/.local/share/claude/versions -type f | sort -V | tail -n 1)' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'if [ -z "$REAL_BIN" ]; then' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo '  echo "Error: No executable found in /home/abc/.local/share/claude/versions/"' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo '  exit 1' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'fi' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'exec "$REAL_BIN" "$@"' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && chmod 755 /usr/local/etc/skel_abc/.local/bin/claude

# 5) 시스템 전역 접근을 위한 심볼릭 링크
RUN ln -s /home/abc/.local/bin/claude /usr/local/bin/claude

# 6) 설정 파일 이동
RUN cp -r /root/.claude /usr/local/etc/skel_abc/ \
    && cp /root/.claude.json /usr/local/etc/skel_abc/ \
    && cp /root/.claude.json.backup /usr/local/etc/skel_abc/ \
    && chown -R abc:abc /usr/local/etc/skel_abc

# 11~13. Expose, Entrypoint
EXPOSE 22 8080
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
CMD ["/usr/local/bin/start.sh"]