#!/usr/bin/env bash
set -euo pipefail

# Run once on a fresh Amazon Linux 2023 / Ubuntu EC2 instance.
# The instance role should allow ecr:GetAuthorizationToken and image pull.

if command -v dnf >/dev/null 2>&1; then
  sudo dnf update -y
  sudo dnf install -y docker
elif command -v yum >/dev/null 2>&1; then
  sudo yum update -y
  sudo yum install -y docker
else
  sudo apt-get update -y
  sudo apt-get install -y docker.io
fi

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER" || true

if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
  sudo mkdir -p /usr/local/lib/docker/cli-plugins
  sudo curl -SL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

if ! command -v aws >/dev/null 2>&1; then
  curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  sudo yum install -y unzip || sudo apt-get install -y unzip
  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
fi

echo "Bootstrap complete. Log out and back in if docker group was just added."
