# docker/Dockerfile
# OpenClaw base image for multi-bot deployment
# Uses runtime volume mounts for state restoration (Approach A)

FROM node:24-bookworm-slim

LABEL org.opencontainers.image.title="OpenClaw Bot"
LABEL org.opencontainers.image.description="OpenClaw gateway for multi-bot Docker deployment"
LABEL org.opencontainers.image.source="https://github.com/vcaldo/continuo"

# Build arguments
ARG UID=1000
ARG GID=1000
ARG OPENCLAW_VERSION=latest

# Environment
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENCLAW_HOME=/home/admin/.openclaw
ENV PATH="${OPENCLAW_HOME}/bin:${PATH}"
ENV BOT_NAME=""
ENV GATEWAY_PORT=8080

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    curl \
    ca-certificates \
    gosu \
    cron \
    procps \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create admin user with configurable UID/GID
RUN groupadd -g ${GID} admin && \
    useradd -m -u ${UID} -g admin -s /bin/bash admin

# Install OpenClaw as admin user
USER admin
WORKDIR /home/admin

# Set shell options for safer pipe handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install OpenClaw using official installer
RUN curl -fsSL https://get.openclaw.ai | bash

# Back to root for entrypoint setup
USER root

# Copy scripts
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/restore-backup.sh /usr/local/bin/restore-backup.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY configs/supervisord.conf /etc/supervisor/conf.d/openclaw.conf

RUN chmod +x /usr/local/bin/*.sh

# Create volume mount points
RUN mkdir -p /data /backups && \
    chown admin:admin /data /backups

# Volumes
# /data - persistent bot data (mounted from named volume)
# /backups - backup tarball mount point (read-only)
VOLUME ["/data", "/backups"]

EXPOSE ${GATEWAY_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
