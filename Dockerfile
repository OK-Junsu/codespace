# support.misolves.com/codespace:0.0.18

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

# 6. Create Staging Directory Structure
# .local/bin 디렉토리 구조를 미리 생성합니다.
RUN mkdir -p /usr/local/etc/skel_abc/.config/code-server \
    && mkdir -p /usr/local/etc/skel_abc/.local/bin \
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

# 8-1. Add User Local PATH to .bashrc AND .profile
# $HOME/.local/bin 경로를 PATH에 추가합니다.
RUN echo '' >> /usr/local/etc/skel_abc/.profile \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /usr/local/etc/skel_abc/.profile \
    && echo '' >> /usr/local/etc/skel_abc/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /usr/local/etc/skel_abc/.bashrc

# 9. Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 10. Install Claude Code & Setup (Dangling Symlink 해결 버전)
# 1) 설치 스크립트 실행
RUN curl -fsSL https://claude.ai/install.sh | bash

# 2) 디렉토리 구조 생성
RUN mkdir -p /usr/local/etc/skel_abc/.local/bin \
    && mkdir -p /usr/local/etc/skel_abc/.local/share

# 3) [핵심] 엔진(share) 이동 및 권한 설정
# 심볼릭 링크가 가리키는 '진짜 파일'들은 여기에 있습니다.
# 폴더 전체에 755 권한을 주어 abc 사용자가 읽고 실행할 수 있게 합니다.
RUN mv /root/.local/share/claude /usr/local/etc/skel_abc/.local/share/claude \
    && chmod -R 755 /usr/local/etc/skel_abc/.local/share/claude

# 4) [핵심] 깨진 심볼릭 링크 대신 '래퍼 스크립트' 생성
# 기존 /root/.local/bin/claude는 링크가 깨지므로 사용하지 않습니다.
# 대신 버전에 상관없이 실행 파일을 찾아 실행하는 스크립트를 만듭니다.
# 주의: 경로는 나중에 start.sh가 복사할 최종 경로(/home/abc/...)를 바라보게 합니다.
RUN echo '#!/bin/sh' > /usr/local/etc/skel_abc/.local/bin/claude \
    && echo 'exec "/home/abc/.local/share/claude/versions/"*"/claude" "$@"' >> /usr/local/etc/skel_abc/.local/bin/claude \
    && chmod 755 /usr/local/etc/skel_abc/.local/bin/claude

# 5) 시스템 전역 접근을 위한 심볼릭 링크 (root 등 사용 가능)
RUN ln -s /home/abc/.local/bin/claude /usr/local/bin/claude

# 6) 설정 파일 이동
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