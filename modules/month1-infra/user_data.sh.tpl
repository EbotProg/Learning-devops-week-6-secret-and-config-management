#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl unzip git

# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker ubuntu

# AWS CLI (not preinstalled on plain Ubuntu)
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# Pull the app repo (has docker-compose.yml, already pinned to mongo:7.0)
sudo -u ubuntu git clone https://github.com/EbotProg/Learning-Devops-Week-3-Docker-Deep-Dive.git /home/ubuntu/app
cd /home/ubuntu/app

# ECR login — uses THIS INSTANCE'S attached IAM role, no keys involved at all
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${region}.amazonaws.com

# --- Week 6: fetch every secret at boot, from Secrets Manager / Parameter ---
# --- Store — nothing hardcoded here anymore, unlike the Week 5 version.   ---
MONGO_ROOT_PASSWORD="$(aws secretsmanager get-secret-value \
  --secret-id "${environment}/parse-stack/mongo-root-password" \
  --region ${region} --query SecretString --output text)"

PARSE_MASTER_KEY="$(aws ssm get-parameter \
  --name "/${environment}/parse-stack/parse-master-key" \
  --with-decryption --region ${region} --query 'Parameter.Value' --output text)"

PARSE_APP_ID="$(aws ssm get-parameter \
  --name "/${environment}/parse-stack/parse-app-id" \
  --with-decryption --region ${region} --query 'Parameter.Value' --output text)"

DASHBOARD_USER="$(aws ssm get-parameter \
  --name "/${environment}/parse-stack/dashboard-user" \
  --with-decryption --region ${region} --query 'Parameter.Value' --output text)"

DASHBOARD_PASSWORD="$(aws ssm get-parameter \
  --name "/${environment}/parse-stack/dashboard-password" \
  --with-decryption --region ${region} --query 'Parameter.Value' --output text)"

cat > .env <<ENVEOF
ECR_REGISTRY=${account_id}.dkr.ecr.${region}.amazonaws.com
IMAGE_TAG=latest
MONGO_ROOT_PASSWORD=$MONGO_ROOT_PASSWORD
PARSE_MASTER_KEY=$PARSE_MASTER_KEY
PARSE_APP_ID=$PARSE_APP_ID
DASHBOARD_USER=$DASHBOARD_USER
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
ENVEOF
chown ubuntu:ubuntu .env
chmod 600 .env

docker compose up -d
