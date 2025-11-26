FROM python:3.13-slim

WORKDIR /app

# Install system dependencies if any (none strictly required for basic usage, but good practice to have basics)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . .

# Install the package
RUN pip install --no-cache-dir .

# Set entrypoint
ENTRYPOINT ["weevely"]
CMD ["--help"]
