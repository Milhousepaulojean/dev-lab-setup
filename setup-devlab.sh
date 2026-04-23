#!/bin/bash
# ============================================
# ATLAS DEV LAB SETUP — CONTINUAÇÃO CORRIGIDA
# NÃO usa "set -u" para não quebrar SDKMAN
# ============================================

set -e  # apenas: pare em erro, sem checar variáveis não setadas

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

echo "============================================"
echo " ATLAS DEV LAB — Continuação do setup..."
echo "============================================"
echo ""

# ------------------------------------------------
# Carregar SDKMAN (sem 'set -u')
# ------------------------------------------------
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.sdkman/bin/sdkman-init.sh"
else
  warn "SDKMAN não encontrado em ~/.sdkman. Pulando etapas Maven/Gradle."
fi

# ============================================
# 5. MAVEN + GRADLE
# ============================================
if command -v sdk >/dev/null 2>&1; then
  log "ETAPA 5 — Instalando Maven e Gradle via SDKMAN..."

  sdk install maven  || warn "Maven já instalado ou falhou."
  sdk install gradle || warn "Gradle já instalado ou falhou."

  mvn -v   >/dev/null 2>&1 && log "Maven ok."   || warn "Maven não no PATH ainda."
  gradle -v >/dev/null 2>&1 && log "Gradle ok." || warn "Gradle não no PATH ainda."
else
  warn "SDKMAN não disponível, pulando Maven/Gradle."
fi
echo ""

# ============================================
# 6. NVM + NODE LTS
# ============================================
log "ETAPA 6 — Instalando NVM e Node LTS..."

if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts
nvm alias default node

node -v && log "Node ok."
npm -v  && log "NPM ok."
echo ""

# ============================================
# 7. ANGULAR + NEXTJS + EXTRAS
# ============================================
log "ETAPA 7 — Instalando Angular CLI, NextJS e ferramentas globais..."

npm install -g \
  @angular/cli \
  create-next-app \
  typescript \
  ts-node \
  yarn \
  pnpm

ng version >/dev/null 2>&1 && log "Angular CLI ok." || warn "Angular CLI não respondeu."
echo ""

# ============================================
# 8. ANDROID SDK (sem emulador)
# ============================================
log "ETAPA 8 — Instalando Android SDK (CLI, sem emulador)..."

sudo apt update
sudo apt install -y openjdk-17-jdk unzip

ANDROID_DIR="$HOME/Android/sdk/cmdline-tools"
mkdir -p "$ANDROID_DIR"

if [ ! -d "$ANDROID_DIR/latest" ]; then
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    -O /tmp/cmdtools.zip
  unzip -q /tmp/cmdtools.zip -d "$ANDROID_DIR"
  mv "$ANDROID_DIR/cmdline-tools" "$ANDROID_DIR/latest"
  rm /tmp/cmdtools.zip
  log "Android commandline tools baixado."
else
  warn "Android commandline tools já existe, pulando download..."
fi

# Variáveis de ambiente Android no zshrc
if ! grep -q "ANDROID_HOME" "$HOME/.zshrc"; then
cat >> "$HOME/.zshrc" << 'ZSHEOF'

# Android SDK
export ANDROID_HOME=$HOME/Android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
ZSHEOF
fi

export ANDROID_HOME="$HOME/Android/sdk"
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

yes | sdkmanager --licenses 2>/dev/null || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

log "Android SDK ok."
echo ""

# ============================================
# 9. PODMAN (rootless)
# ============================================
log "ETAPA 9 — Instalando Podman..."

if ! command -v podman >/dev/null 2>&1; then
  sudo apt install -y podman podman-compose
  sudo loginctl enable-linger "$USER"
fi

# Alias docker=podman para conveniência
if ! grep -q "alias docker=podman" "$HOME/.zshrc"; then
  echo "alias docker=podman" >> "$HOME/.zshrc"
fi
if ! grep -q "alias docker-compose=" "$HOME/.zshrc"; then
  echo "alias docker-compose='podman-compose'" >> "$HOME/.zshrc"
fi

podman --version && log "Podman ok."
echo ""

# ============================================
# 10. VS CODE + EXTENSÕES
# ============================================
log "ETAPA 10 — Instalando VS Code..."

if ! command -v code >/dev/null 2>&1; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor > /tmp/packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 \
    /tmp/packages.microsoft.gpg \
    /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
    https://packages.microsoft.com/repos/code stable main" | \
    sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  sudo apt update && sudo apt install -y code
  log "VS Code instalado."
else
  warn "VS Code já instalado, pulando..."
fi

EXTENSIONS=(
  "ms-vscode.vscode-typescript-next"
  "angular.ng-template"
  "github.copilot"
  "eamodio.gitlens"
  "esbenp.prettier-vscode"
  "dbaeumer.vscode-eslint"
  "redhat.java"
  "vscjava.vscode-spring-initializr"
  "amazonwebservices.aws-toolkit-vscode"
  "ms-azuretools.vscode-docker"
  "rangav.vscode-thunder-client"
)

for ext in "${EXTENSIONS[@]}"; do
  code --install-extension "$ext" --force >/dev/null 2>&1 \
    && log "Extensão instalada: $ext" \
    || warn "Extensão falhou: $ext"
done
echo ""

# ============================================
# 11. INTELLIJ IDEA COMMUNITY
# ============================================
log "ETAPA 11 — Instalando IntelliJ IDEA Community..."

if ! snap list 2>/dev/null | grep -q "intellij-idea-community"; then
  sudo snap install intellij-idea-community --classic
  log "IntelliJ instalado."
else
  warn "IntelliJ já instalado, pulando..."
fi
echo ""

# ============================================
# 12. AWS CLI v2
# ============================================
log "ETAPA 12 — Instalando AWS CLI..."

if ! command -v aws >/dev/null 2>&1; then
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/
  sudo /tmp/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/aws
  log "AWS CLI instalado."
else
  warn "AWS CLI já instalado, pulando..."
fi
echo ""

# ============================================
# 13. LIMPEZA + VERIFICAÇÃO
# ============================================
log "ETAPA 13 — Limpeza..."
sudo apt autoremove -y
sudo apt clean

echo ""
echo "============================================"
echo " VERIFICAÇÃO FINAL"
echo "============================================"

check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo -e "${GREEN}[✅]${NC} $1"
  else
    echo -e "${RED}[❌]${NC} $1 — não encontrado"
  fi
}

check git
check java
check mvn
check gradle
check node
check npm
check ng
check podman
check code
check aws
check zsh

echo ""
log "Espaço restante no SSD:"
df -h / | tail -1

echo ""
echo "============================================"
echo " ✅ DEV LAB COMPLETO!"
echo "============================================"
echo ""
echo " Próximos passos manuais:"
echo "   aws configure   → configurar credenciais AWS"
echo "   gh auth login   → se ainda não autenticou GitHub CLI"
echo ""
read -rp "Pressione ENTER para encerrar (sem reboot automático)..."
exit 0
