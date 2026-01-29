# SQL Server 2022 on Ubuntu 22.04
FROM mcr.microsoft.com/mssql/server:2022-latest

# Metadata
LABEL maintainer="CAP-DAMS Team"
LABEL description="SQL Server 2022 Developer Edition for DAMS Testing"
LABEL version="1.0"

# Switch to root for system configuration
USER root

# Install additional utilities for DBA operations
RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    gnupg \
    vim \
    nano \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create directories for backups, scripts, and custom configurations
RUN mkdir -p /var/opt/mssql/backup \
    && mkdir -p /var/opt/mssql/scripts \
    && mkdir -p /var/opt/mssql/data \
    && mkdir -p /var/opt/mssql/log \
    && mkdir -p /docker-entrypoint-initdb.d \
    && chown -R mssql:mssql /var/opt/mssql

# Copy custom SQL Server configuration file (if needed)
COPY --chown=mssql:mssql mssql.conf /var/opt/mssql/mssql.conf

# Copy initialization scripts
COPY --chown=mssql:mssql init-scripts/ /docker-entrypoint-initdb.d/

# Expose SQL Server port
EXPOSE 1433

# Switch back to mssql user for security
USER mssql

# Use the default SQL Server entrypoint
# ENTRYPOINT is inherited from base image

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" || exit 1
