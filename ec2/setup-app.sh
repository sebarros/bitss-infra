#!/bin/bash
set -euo pipefail
AWS_REGION="${AWS_REGION:-us-east-1}"
dnf install -y docker awscli
systemctl enable --now docker
docker network create bitss-net 2>/dev/null || true
mkdir -p /opt/bitss
chmod 700 /opt/bitss
printf '%s' "$AWS_REGION" > /etc/bitss-region
cat > /opt/bitss/deploy-service.sh <<'DEPLOY'
#!/bin/bash
set -euo pipefail
SERVICE="$1"
IMAGE="$2"
PORT="$3"
ENV_FILE="/opt/bitss/${SERVICE}.env"
test -f "$ENV_FILE"
REGION="$(cat /etc/bitss-region)"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
docker pull "$IMAGE"
docker rm -f "$SERVICE" 2>/dev/null || true
docker run -d --name "$SERVICE" --restart unless-stopped --network bitss-net --env-file "$ENV_FILE" -p "${PORT}:${PORT}" "$IMAGE"
for attempt in $(seq 1 60); do
  if [ "$(docker inspect -f '{{.State.Running}}' "$SERVICE" 2>/dev/null || true)" != "true" ]; then
    docker logs "$SERVICE" || true
    exit 1
  fi
  if bash -c "echo > /dev/tcp/127.0.0.1/$PORT" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 5
done
docker logs "$SERVICE"
exit 1
DEPLOY
chmod 750 /opt/bitss/deploy-service.sh
