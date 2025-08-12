# TrueNAS Charts Validation Tools Docker Image
# For maintaining TrueNAS Dragonfish 24.04 charts repository
# Based on the official ixsystems/catalog_validation image

FROM python:3.11-slim

LABEL maintainer="secretzer0 <tmelhiser@gmail.com>"
LABEL description="Custom validation tools for TrueNAS Dragonfish charts"
LABEL version="1.0.0"

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone the catalog_validation repository
# We'll use a specific commit for stability
RUN git clone https://github.com/truenas/catalog_validation.git /app/catalog_validation && \
    cd /app/catalog_validation && \
    git checkout HEAD

# Install Python dependencies
RUN cd /app/catalog_validation && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -e .

# Create wrapper scripts that handle the main branch properly
RUN echo '#!/bin/bash\n\
set -e\n\
# Set default branch to main\n\
export DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"\n\
# Execute the original validation script\n\
cd /app/catalog_validation\n\
python -m catalog_validation.scripts.catalog_validate "$@"' > /usr/local/bin/catalog_validate && \
    chmod +x /usr/local/bin/catalog_validate

RUN echo '#!/bin/bash\n\
set -e\n\
# Set default branch to main\n\
export DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"\n\
# Execute the original dev charts validation script\n\
cd /app/catalog_validation\n\
python -m catalog_validation.scripts.dev_charts_validate "$@"' > /usr/local/bin/dev_charts_validate && \
    chmod +x /usr/local/bin/dev_charts_validate

# Add a health check script
RUN echo '#!/bin/bash\n\
echo "Validation tools container is ready"\n\
catalog_validate --help > /dev/null 2>&1 && echo "catalog_validate: OK" || echo "catalog_validate: FAILED"\n\
dev_charts_validate --help > /dev/null 2>&1 && echo "dev_charts_validate: OK" || echo "dev_charts_validate: FAILED"' > /usr/local/bin/health_check && \
    chmod +x /usr/local/bin/health_check

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEFAULT_BRANCH=main

# Default command
CMD ["/usr/local/bin/health_check"]