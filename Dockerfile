# support.misolves.com/codespace:0.0.7

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

# 6. Create directory and Configure code-server for the 'abc' user
RUN mkdir -p /home/abc/.config/code-server \
    && chown -R abc:abc /home/abc

# 7. Create code-server config file (only password, bind-addr will be set in start.sh)
RUN echo "auth: password" > /home/abc/.config/code-server/config.yaml \
    && echo "password: your_password" >> /home/abc/.config/code-server/config.yaml \
    && chown abc:abc /home/abc/.config/code-server/config.yaml \
    && chmod 600 /home/abc/.config/code-server/config.yaml

# 8. Configure SSH (Existing)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 9. Install Claude Code for the 'abc' user
USER abc
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

# 10. Set PATH for Claude Code in .bashrc
RUN echo 'export PATH="/home/abc/.local/bin:$PATH"' >> /home/abc/.bashrc \
    && chown abc:abc /home/abc/.bashrc

# 11. Expose SSH Port (22) and code-server Port (8080)
EXPOSE 22 8080

# 12. Entrypoint Script for Integrated Services
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 13. Run the Wrapper Script
CMD ["/usr/local/bin/start.sh"]