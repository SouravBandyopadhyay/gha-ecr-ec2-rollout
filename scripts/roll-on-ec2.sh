#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${IMAGE:?IMAGE is required}"
: "${GIT_SHA:?GIT_SHA is required}"

APP_DIR="${APP_DIR:-/opt/ecr-ec2}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker pull "$IMAGE"

export IMAGE GIT_SHA APP_VERSION="${APP_VERSION:-$GIT_SHA}"

if docker compose version >/dev/null 2>&1; then
  docker compose up -d --force-recreate --remove-orphans
else
  docker-compose up -d --force-recreate --remove-orphans
fi

docker image prune -f >/dev/null || true
echo "Rolled $IMAGE"
