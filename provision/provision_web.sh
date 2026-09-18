#!/bin/bash
set -e

echo ">>> Actualizando el sistema..."
apt-get update -y
apt-get upgrade -y

echo ">>> Instalando dependencias base..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    apt-transport-https \
    ftp \
    nano \
    git

# -----------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------
echo ">>> Instalando Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker vagrant

# -----------------------------------------------------------------------
# kubectl (anclado a la misma minor version que usa Minikube, ver README)
# -----------------------------------------------------------------------
echo ">>> Instalando kubectl..."
K8S_MINOR_VERSION="v1.31"
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
apt-get update -y
apt-get install -y kubectl

# -----------------------------------------------------------------------
# Minikube
# -----------------------------------------------------------------------
echo ">>> Instalando Minikube (amd64)..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64

echo ">>> Aprovisionamiento completado."
echo ">>> Conéctate con 'vagrant ssh servidorUbuntu' y sigue el README.md para levantar cada servicio."
