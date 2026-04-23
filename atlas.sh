#!/bin/bash
set -e

ATLAS_VERSION="1.2.0"
LOG_DIR="$HOME/.local/log/atlas"
LOG_OPTIMIZER="${LOG_DIR}/optimizer.log"
LOG_BACKUP="${LOG_DIR}/backup.log"
LAST_OPTIMIZER="${LOG_DIR}/last-optimizer.txt"
LAST_BACKUP="${LOG_DIR}/last-backup.txt"
SYSTEMD_DIR="$HOME/.config/systemd/user"
OPTIMIZER_SERVICE="${SYSTEMD_DIR}/atlas-optimizer.service"
OPTIMIZER_TIMER="${SYSTEMD_DIR}/atlas-optimizer.timer"
BACKUP_SERVICE="${SYSTEMD_DIR}/atlas-backup.service"
BACKUP_TIMER="${SYSTEMD_DIR}/atlas-backup.timer"
REMOTE_NAME="gdrive"
REMOTE_PATH="atlas-backup"

BACKUP_DIRS=(
  "$HOME/workspace"
  "$HOME/Documents"
  "$HOME/dev-lab-setup"
  "$HOME/atlas.sh"
)

BACKUP_EXCLUDES=(
  ".git/"
  "node_modules/"
  "dist/"
  "build/"
  "target/"
  ".gradle/"
  ".idea/"
  ".vscode/"
  ".DS_Store"
  "*.log"
  "*.tmp"
  "*.bak"
  "*.iso"
  "*.img"
  "*.zip"
  "*.tar"
  "*.tar.gz"
  ".sdkman/"
  ".nvm/"
  ".cache/"
)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
CURRENT_LOG="/dev/null"

log()     { echo -e "${GREEN}[OK]${NC} $1"     | tee -a "$CURRENT_LOG"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1" | tee -a "$CURRENT_LOG"; }
info()    { echo -e "${BLUE}[INFO]${NC} $1"    | tee -a "$CURRENT_LOG"; }
fail()    { echo -e "${RED}[ERRO]${NC} $1"     | tee -a "$CURRENT_LOG"; }
section() {
  echo -e "\n${BOLD}============================================${NC}" | tee -a "$CURRENT_LOG"
  echo -e "${BOLD} $1${NC}" | tee -a "$CURRENT_LOG"
  echo -e "${BOLD}============================================${NC}\n" | tee -a "$CURRENT_LOG"
}

mkdir -p "$LOG_DIR" "$HOME/.local/bin" "$SYSTEMD_DIR"

show_menu() {
  clear
  echo ""
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║         ATLAS MACHINE CONTROL            ║"
  echo "  ║     MacBookPro12,1 | Ubuntu 24.04        ║"
  echo "  ║     i5 2.7GHz | 8GB RAM | 120GB SSD     ║"
  echo "  ║     v${ATLAS_VERSION}                             ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${CYAN}── DEV LAB ──────────────────────────────${NC}"
  echo -e "  ${GREEN}[1]${NC}  Instalar Dev Lab completo"
  echo ""
  echo -e "  ${CYAN}── PERFORMANCE ──────────────────────────${NC}"
  echo -e "  ${GREEN}[2]${NC}  Otimizar maquina agora"
  echo ""
  echo -e "  ${CYAN}── BACKUP ───────────────────────────────${NC}"
  echo -e "  ${GREEN}[3]${NC}  Backup para Google Drive agora"
  echo -e "  ${GREEN}[4]${NC}  Simular backup (dry run)"
  echo -e "  ${GREEN}[5]${NC}  Ver conteudo do backup no Drive"
  echo -e "  ${RED}[6]${NC}   Remover backup do Google Drive"
  echo ""
  echo -e "  ${CYAN}── AGENDADORES ──────────────────────────${NC}"
  echo -e "  ${GREEN}[7]${NC}  Instalar agendadores automaticos"
  echo -e "  ${GREEN}[8]${NC}  Remover agendadores"
  echo -e "  ${GREEN}[9]${NC}  Status dos agendadores"
  echo ""
  echo -e "  ${CYAN}── LOGS ─────────────────────────────────${NC}"
  echo -e "  ${GREEN}[10]${NC} Ver ultimo log do otimizador"
  echo -e "  ${GREEN}[11]${NC} Ver ultimo log do backup"
  echo ""
  echo -e "  ${CYAN}── INSTALACAO ───────────────────────────${NC}"
  echo -e "  ${GREEN}[12]${NC} Instalar atlas como comando global"
  echo -e "  ${YELLOW}[13]${NC} Desinstalar comando global"
  echo ""
  echo -e "  ${RED}[0]${NC}  Sair"
  echo ""
  if command -v atlas >/dev/null 2>&1; then
    echo -e "  ${GREEN}atlas instalado globalmente${NC} ($(which atlas))"
  else
    echo -e "  ${YELLOW}atlas nao instalado globalmente${NC}"
  fi
  echo ""
  read -rp "  Opcao: " OPTION
  echo ""
  case "$OPTION" in
    1)  run_setup           ;;
    2)  run_optimizer       ;;
    3)  run_backup          ;;
    4)  run_backup_dry      ;;
    5)  view_backup_drive   ;;
    6)  remove_backup_drive ;;
    7)  install_timers      ;;
    8)  remove_timers       ;;
    9)  show_status         ;;
    10) show_log_optimizer  ;;
    11) show_log_backup     ;;
    12) install_global      ;;
    13) uninstall_global    ;;
    0)  echo -e "  ${BOLD}Ate logo!${NC}"; echo ""; exit 0 ;;
    *)  warn "Opcao invalida."; sleep 1; show_menu ;;
  esac
}

run_setup() {
  CURRENT_LOG="$LOG_OPTIMIZER"
  echo "" >> "$CURRENT_LOG"
  echo "=== SETUP INICIO: $(date '+%d/%m/%Y %H:%M:%S') ===" >> "$CURRENT_LOG"
  clear
  echo -e "${BOLD}  ATLAS DEV LAB — Setup Completo${NC}"
  echo ""

  section "ETAPA 1 — Sistema base"
  sudo apt update -qq && sudo apt upgrade -y -qq
  sudo apt install -y -qq curl wget git unzip zip build-essential zsh ca-certificates gnupg lsb-release software-properties-common
  log "Sistema atualizado."

  section "ETAPA 2 — Zsh + Oh My Zsh"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log "Oh My Zsh instalado."
  else
    warn "Oh My Zsh ja instalado."
  fi
  if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" && log "Shell padrao zsh."
  fi

  section "ETAPA 3 — Git + GitHub CLI"
  git config --global init.defaultBranch main
  git config --global core.editor "nano"
  git config --global pull.rebase false
  if ! command -v gh >/dev/null 2>&1; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install -y -qq gh
    log "GitHub CLI instalado."
  else
    warn "GitHub CLI ja instalado."
  fi

  section "ETAPA 4 — SDKMAN + Java 21 + Maven + Gradle"
  if [ ! -d "$HOME/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
    log "SDKMAN instalado."
  else
    warn "SDKMAN ja instalado."
  fi
  if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
  fi
  sdk install java 21.0.3-tem || warn "Java 21 ja instalado."
  sdk install maven            || warn "Maven ja instalado."
  sdk install gradle           || warn "Gradle ja instalado."

  section "ETAPA 5 — NVM + Node LTS"
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  else
    warn "NVM ja instalado."
  fi
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts && nvm use --lts && nvm alias default node
  npm install -g @angular/cli create-next-app typescript ts-node yarn pnpm
  log "Node + Angular + Next ok."

  section "ETAPA 6 — Android SDK"
  sudo apt install -y openjdk-17-jdk
  ANDROID_DIR="$HOME/Android/sdk/cmdline-tools"
  mkdir -p "$ANDROID_DIR"
  if [ ! -d "$ANDROID_DIR/latest" ]; then
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdtools.zip
    unzip -q /tmp/cmdtools.zip -d "$ANDROID_DIR"
    mv "$ANDROID_DIR/cmdline-tools" "$ANDROID_DIR/latest"
    rm /tmp/cmdtools.zip
    log "Android SDK instalado."
  else
    warn "Android SDK ja existe."
  fi
  grep -q "ANDROID_HOME" "$HOME/.zshrc" || {
    echo "export ANDROID_HOME=\$HOME/Android/sdk" >> "$HOME/.zshrc"
    echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin" >> "$HOME/.zshrc"
    echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools" >> "$HOME/.zshrc"
  }
  export ANDROID_HOME="$HOME/Android/sdk"
  export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
  yes | sdkmanager --licenses 2>/dev/null || true
  sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
  log "Android SDK ok."

  section "ETAPA 7 — Podman"
  if ! command -v podman >/dev/null 2>&1; then
    sudo apt install -y podman podman-compose
    sudo loginctl enable-linger "$USER"
    log "Podman instalado."
  else
    warn "Podman ja instalado."
  fi
  grep -q "alias docker=podman" "$HOME/.zshrc" || echo "alias docker=podman" >> "$HOME/.zshrc"

  section "ETAPA 8 — VS Code"
  if ! command -v code >/dev/null 2>&1; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt update -qq && sudo apt install -y code
    log "VS Code instalado."
  else
    warn "VS Code ja instalado."
  fi
  for ext in "ms-vscode.vscode-typescript-next" "angular.ng-template" "github.copilot" "eamodio.gitlens" "esbenp.prettier-vscode" "dbaeumer.vscode-eslint" "redhat.java" "vscjava.vscode-spring-initializr" "amazonwebservices.aws-toolkit-vscode" "ms-azuretools.vscode-docker" "rangav.vscode-thunder-client"; do
    code --install-extension "$ext" --force >/dev/null 2>&1 && log "Extensao: $ext" || warn "Falhou: $ext"
  done

  section "ETAPA 9 — IntelliJ"
  snap list 2>/dev/null | grep -q "intellij-idea-community" || sudo snap install intellij-idea-community --classic
  log "IntelliJ ok."

  section "ETAPA 10 — AWS CLI"
  if ! command -v aws >/dev/null 2>&1; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
    log "AWS CLI instalado."
  else
    warn "AWS CLI ja instalado."
  fi

  section "ETAPA 11 — rclone"
  command -v rclone >/dev/null 2>&1 || sudo apt install -y rclone
  log "rclone ok."

  sudo apt autoremove -y -qq && sudo apt clean

  section "VERIFICACAO FINAL"
  for cmd in git java mvn gradle node npm ng podman code aws rclone zsh; do
    command -v "$cmd" >/dev/null 2>&1 \
      && echo -e "  ${GREEN}[OK]${NC} $cmd" \
      || echo -e "  ${RED}[FALTA]${NC} $cmd"
  done

  echo ""
  echo -e "${BOLD}  DEV LAB CONCLUIDO!${NC}"
  echo -e "  ${CYAN}aws configure${NC}  credenciais AWS"
  echo -e "  ${CYAN}gh auth login${NC}  autenticar GitHub"
  echo -e "  ${CYAN}rclone config${NC}  configurar Google Drive"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

run_optimizer() {
  CURRENT_LOG="$LOG_OPTIMIZER"
  echo "" >> "$CURRENT_LOG"
  echo "=== OPTIMIZER INICIO: $(date '+%d/%m/%Y %H:%M:%S') ===" >> "$CURRENT_LOG"
  clear
  echo -e "${BOLD}  ATLAS PERFORMANCE OPTIMIZER${NC}"
  echo ""

  RAM_USED=$(free -h | awk '/^Mem:/{print $3}')
  RAM_FREE=$(free -h | awk '/^Mem:/{print $4}')
  SSD_FREE=$(df -h / | awk 'NR==2{print $4}')
  SSD_PERCENT=$(df / | awk 'NR==2{print $5}')

  info "RAM: Usada=$RAM_USED | Livre=$RAM_FREE"
  info "SSD: Livre=$SSD_FREE | Uso=$SSD_PERCENT"

  section "Sistema e Pacotes"
  sudo apt update -qq && sudo apt autoremove -y -qq && sudo apt clean && sudo apt autoclean -qq
  log "Pacotes limpos."

  section "Memoria e SWAP"
  sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
  log "Cache RAM liberado."
  SWAPPINESS=$(cat /proc/sys/vm/swappiness)
  if [ "$SWAPPINESS" -gt 10 ]; then
    sudo sysctl vm.swappiness=10 > /dev/null
    grep -q "vm.swappiness" /etc/sysctl.conf \
      && sudo sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf \
      || echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null
    log "Swappiness 10"
  fi
  grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf \
    || echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null
  sudo sysctl vm.vfs_cache_pressure=50 > /dev/null
  log "VFS cache pressure 50"

  section "SSD TRIM"
  systemctl is-enabled fstrim.timer >/dev/null 2>&1 || sudo systemctl enable --now fstrim.timer
  sudo fstrim -v / 2>/dev/null && log "TRIM executado." || warn "TRIM aviso."
  DISK=$(lsblk -d -o name | grep -v NAME | head -1)
  [ -f "/sys/block/$DISK/queue/scheduler" ] && \
    echo "none" | sudo tee /sys/block/$DISK/queue/scheduler > /dev/null 2>&1 && \
    log "I/O Scheduler none"

  section "CPU Governor"
  if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      echo "ondemand" | sudo tee "$cpu" > /dev/null 2>&1 || true
    done
    log "CPU Governor ondemand"
  fi

  section "Servicos"
  for svc in bluetooth cups cups-browsed avahi-daemon ModemManager; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      sudo systemctl stop "$svc" 2>/dev/null || true
      sudo systemctl disable "$svc" 2>/dev/null || true
      warn "Desativado: $svc"
    else
      info "Inativo: $svc"
    fi
  done

  section "Temporarios e Logs"
  sudo find /tmp -type f -atime +2 -delete 2>/dev/null || true
  sudo journalctl --vacuum-time=3d > /dev/null 2>&1
  sudo journalctl --vacuum-size=100M > /dev/null 2>&1
  rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
  log "Temporarios limpos."

  section "DNS"
  DNS_FILE="/etc/systemd/resolved.conf"
  if [ -f "$DNS_FILE" ] && ! grep -q "^DNS=1.1.1.1" "$DNS_FILE"; then
    sudo sed -i 's/^#DNS=.*/DNS=1.1.1.1 8.8.8.8/' "$DNS_FILE"
    sudo sed -i 's/^#FallbackDNS=.*/FallbackDNS=1.0.0.1 8.8.4.4/' "$DNS_FILE"
    sudo systemctl restart systemd-resolved
    log "DNS Cloudflare + Google"
  else
    log "DNS ja otimizado."
  fi

  RAM_USED_AFTER=$(free -h | awk '/^Mem:/{print $3}')
  RAM_FREE_AFTER=$(free -h | awk '/^Mem:/{print $4}')
  SSD_FREE_AFTER=$(df -h / | awk 'NR==2{print $4}')
  SSD_PERCENT_AFTER=$(df / | awk 'NR==2{print $5}')

  REPORT="
============================================
  ATLAS OPTIMIZER — $(date '+%d/%m/%Y %H:%M:%S')
============================================
  RAM: $RAM_USED -> $RAM_USED_AFTER usada
  RAM: $RAM_FREE -> $RAM_FREE_AFTER livre
  SSD: $SSD_FREE -> $SSD_FREE_AFTER livre
  SSD: $SSD_PERCENT -> $SSD_PERCENT_AFTER uso
  [OK] Pacotes limpos
  [OK] Cache RAM liberado
  [OK] Swappiness 10
  [OK] VFS 50
  [OK] TRIM SSD executado
  [OK] I/O Scheduler none
  [OK] CPU Governor ondemand
  [OK] Servicos desativados
  [OK] Temporarios limpos
  [OK] DNS Cloudflare + Google
============================================"
  echo "$REPORT" | tee -a "$CURRENT_LOG"
  echo "$REPORT" > "$LAST_OPTIMIZER"

  echo ""
  echo -e "${BOLD}  Otimizacao concluida!${NC}"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

run_backup()     { _do_backup "NORMAL"; }
run_backup_dry() { _do_backup "DRYRUN"; }

_do_backup() {
  local MODE="$1"
  CURRENT_LOG="$LOG_BACKUP"
  echo "" >> "$CURRENT_LOG"
  echo "=== BACKUP INICIO: $(date '+%d/%m/%Y %H:%M:%S') ===" >> "$CURRENT_LOG"
  clear
  echo -e "${BOLD}  ATLAS BACKUP GOOGLE DRIVE — Modo: ${MODE}${NC}"
  echo ""

  if ! command -v rclone >/dev/null 2>&1; then
    fail "rclone nao encontrado. Execute opcao 1."
    read -rp "  ENTER..."; show_menu; return
  fi
  if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    fail "Remote ${REMOTE_NAME} nao configurado. Execute: rclone config"
    read -rp "  ENTER..."; show_menu; return
  fi

  RCLONE_EXCLUDES=()
  for ex in "${BACKUP_EXCLUDES[@]}"; do
    RCLONE_EXCLUDES+=("--exclude" "$ex")
  done

  START_TIME=$(date +%s)
  for dir in "${BACKUP_DIRS[@]}"; do
    [ ! -e "$dir" ] && { warn "Ignorando: $dir"; continue; }
    BASENAME=$(basename "$dir")
    DEST="${REMOTE_NAME}:${REMOTE_PATH}/${BASENAME}"
    info "Backup: $dir -> $DEST"
    if [ "$MODE" = "DRYRUN" ]; then
      rclone sync "$dir" "$DEST" --dry-run --progress "${RCLONE_EXCLUDES[@]}" 2>&1 | tee -a "$CURRENT_LOG"
    else
      rclone sync "$dir" "$DEST" --progress --create-empty-src-dirs --use-server-modtime --fast-list "${RCLONE_EXCLUDES[@]}" 2>&1 | tee -a "$CURRENT_LOG"
    fi
  done
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  REPORT="
============================================
  ATLAS BACKUP — $(date '+%d/%m/%Y %H:%M:%S')
  Remote: ${REMOTE_NAME}:${REMOTE_PATH}
  Modo: ${MODE} | Duracao: ${DURATION}s
============================================"
  echo "$REPORT" | tee -a "$CURRENT_LOG"
  echo "$REPORT" > "$LAST_BACKUP"

  echo ""
  echo -e "${BOLD}  Backup finalizado!${NC}"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

view_backup_drive() {
  CURRENT_LOG="/dev/null"
  clear
  echo -e "${BOLD}  CONTEUDO DO BACKUP NO GOOGLE DRIVE${NC}"
  echo ""
  if ! command -v rclone >/dev/null 2>&1; then
    fail "rclone nao encontrado."; read -rp "  ENTER..."; show_menu; return
  fi
  if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    fail "Remote nao configurado."; read -rp "  ENTER..."; show_menu; return
  fi
  echo -e "${BOLD}  Pastas:${NC}"
  rclone lsd "${REMOTE_NAME}:${REMOTE_PATH}" 2>/dev/null || warn "Pasta nao encontrada. Rode backup primeiro."
  echo ""
  echo -e "${BOLD}  Tamanho total:${NC}"
  rclone size "${REMOTE_NAME}:${REMOTE_PATH}" 2>/dev/null || warn "Nao calculado."
  echo ""
  read -rp "  Listar arquivos detalhados? (s/N): " DETAIL
  if [[ "$DETAIL" =~ ^[sS]$ ]]; then
    rclone ls "${REMOTE_NAME}:${REMOTE_PATH}" 2>/dev/null | head -50
    warn "Primeiros 50 arquivos."
  fi
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

remove_backup_drive() {
  CURRENT_LOG="$LOG_BACKUP"
  clear
  echo -e "${BOLD}${RED}  REMOVER BACKUP DO GOOGLE DRIVE${NC}"
  echo ""
  if ! command -v rclone >/dev/null 2>&1; then
    fail "rclone nao encontrado."; read -rp "  ENTER..."; show_menu; return
  fi
  if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    fail "Remote nao configurado."; read -rp "  ENTER..."; show_menu; return
  fi
  echo -e "  ${GREEN}[1]${NC} Remover uma pasta especifica"
  echo -e "  ${GREEN}[2]${NC} Remover um arquivo especifico"
  echo -e "  ${RED}[3]${NC} Remover TODO o backup"
  echo -e "  ${YELLOW}[0]${NC} Cancelar"
  echo ""
  read -rp "  Opcao: " REMOVE_OPTION
  case "$REMOVE_OPTION" in
    1) _remove_backup_folder ;;
    2) _remove_backup_file   ;;
    3) _remove_backup_all    ;;
    0) show_menu             ;;
    *) warn "Invalido."; sleep 1; remove_backup_drive ;;
  esac
}

_remove_backup_folder() {
  echo ""
  echo -e "${BOLD}  Pastas no backup:${NC}"
  rclone lsd "${REMOTE_NAME}:${REMOTE_PATH}" 2>/dev/null || { warn "Nenhuma pasta."; read -rp "  ENTER..."; show_menu; return; }
  echo ""
  read -rp "  Nome da pasta: " FOLDER_NAME
  [ -z "$FOLDER_NAME" ] && { warn "Nenhuma pasta informada."; read -rp "  ENTER..."; show_menu; return; }
  DEST="${REMOTE_NAME}:${REMOTE_PATH}/${FOLDER_NAME}"
  echo -e "${RED}  ATENCAO: Irreversivel! Pasta: ${BOLD}$DEST${NC}"
  read -rp "  Digite o nome para confirmar: " CONFIRM
  [ "$CONFIRM" != "$FOLDER_NAME" ] && { warn "Cancelado."; read -rp "  ENTER..."; show_menu; return; }
  rclone purge "$DEST" -v 2>&1 | tee -a "$CURRENT_LOG"
  echo "REMOCAO PASTA: $DEST em $(date '+%d/%m/%Y %H:%M:%S')" >> "$CURRENT_LOG"
  echo -e "${BOLD}  Pasta removida: $FOLDER_NAME${NC}"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

_remove_backup_file() {
  echo ""
  echo -e "  Exemplo: Documents/relatorio.pdf"
  read -rp "  Caminho do arquivo: " FILE_PATH
  [ -z "$FILE_PATH" ] && { warn "Nenhum arquivo."; read -rp "  ENTER..."; show_menu; return; }
  DEST="${REMOTE_NAME}:${REMOTE_PATH}/${FILE_PATH}"
  echo -e "${RED}  ATENCAO: Irreversivel! Arquivo: ${BOLD}$DEST${NC}"
  read -rp "  Confirma? (s/N): " CONFIRM
  [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { warn "Cancelado."; read -rp "  ENTER..."; show_menu; return; }
  rclone deletefile "$DEST" -v 2>&1 | tee -a "$CURRENT_LOG"
  echo "REMOCAO ARQUIVO: $DEST em $(date '+%d/%m/%Y %H:%M:%S')" >> "$CURRENT_LOG"
  echo -e "${BOLD}  Arquivo removido.${NC}"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

_remove_backup_all() {
  echo ""
  echo -e "${RED}  ATENCAO MAXIMA — Remover TODO o backup!${NC}"
  echo -e "  Pasta: ${BOLD}${REMOTE_NAME}:${REMOTE_PATH}${NC}"
  echo ""
  rclone size "${REMOTE_NAME}:${REMOTE_PATH}" 2>/dev/null || true
  echo ""
  echo -e "${RED}  Completamente irreversivel!${NC}"
  read -rp "  Digite CONFIRMAR para prosseguir: " CONFIRM
  [ "$CONFIRM" != "CONFIRMAR" ] && { warn "Cancelado."; read -rp "  ENTER..."; show_menu; return; }
  rclone purge "${REMOTE_NAME}:${REMOTE_PATH}" -v 2>&1 | tee -a "$CURRENT_LOG"
  echo "REMOCAO TOTAL: ${REMOTE_NAME}:${REMOTE_PATH} em $(date '+%d/%m/%Y %H:%M:%S')" >> "$CURRENT_LOG"
  echo -e "${BOLD}  Backup removido por completo.${NC}"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

install_timers() {
  SCRIPT_PATH="$HOME/.local/bin/atlas.sh"
  section "INSTALANDO AGENDADORES"
  cp "$0" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  log "Script copiado para: $SCRIPT_PATH"

  cat > "$OPTIMIZER_SERVICE" << EOF
[Unit]
Description=Atlas Performance Optimizer
After=network.target
[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --optimize
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=default.target
EOF

  cat > "$OPTIMIZER_TIMER" << EOF
[Unit]
Description=Atlas Optimizer Semanal
[Timer]
OnCalendar=Sun 09:00
Persistent=true
RandomizedDelaySec=300
[Install]
WantedBy=timers.target
EOF

  cat > "$BACKUP_SERVICE" << EOF
[Unit]
Description=Atlas Backup Google Drive
After=network-online.target
[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --backup
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=default.target
EOF

  cat > "$BACKUP_TIMER" << EOF
[Unit]
Description=Atlas Backup Diario
[Timer]
OnCalendar=*-*-* 23:00
Persistent=true
RandomizedDelaySec=300
[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable atlas-optimizer.timer && systemctl --user start atlas-optimizer.timer
  systemctl --user enable atlas-backup.timer    && systemctl --user start atlas-backup.timer

  log "Optimizer: Domingo 09:00"
  log "Backup: diario 23:00"
  echo ""
  echo -e "${BOLD}  Agendadores instalados!${NC}"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

remove_timers() {
  section "REMOVENDO AGENDADORES"
  for timer in atlas-optimizer.timer atlas-backup.timer; do
    systemctl --user stop    "$timer" 2>/dev/null || true
    systemctl --user disable "$timer" 2>/dev/null || true
  done
  systemctl --user daemon-reload
  rm -f "$OPTIMIZER_SERVICE" "$OPTIMIZER_TIMER" "$BACKUP_SERVICE" "$BACKUP_TIMER"
  warn "Agendadores removidos."
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

show_status() {
  clear
  echo -e "${BOLD}  STATUS DOS AGENDADORES${NC}"
  echo ""
  echo -e "${BOLD}  Optimizer:${NC}"
  systemctl --user status atlas-optimizer.timer 2>/dev/null || echo -e "  ${RED}Nao instalado.${NC}"
  echo ""
  echo -e "${BOLD}  Backup:${NC}"
  systemctl --user status atlas-backup.timer 2>/dev/null || echo -e "  ${RED}Nao instalado.${NC}"
  echo ""
  echo -e "${BOLD}  Proximas execucoes:${NC}"
  systemctl --user list-timers 2>/dev/null | grep atlas || echo "  Nenhum timer ativo."
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

show_log_optimizer() {
  clear
  echo -e "${BOLD}  ULTIMO RELATORIO — OPTIMIZER${NC}"
  echo ""
  [ -f "$LAST_OPTIMIZER" ] && cat "$LAST_OPTIMIZER" || warn "Nenhum relatorio. Execute opcao 2."
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

show_log_backup() {
  clear
  echo -e "${BOLD}  ULTIMO RELATORIO — BACKUP${NC}"
  echo ""
  [ -f "$LAST_BACKUP" ] && cat "$LAST_BACKUP" || warn "Nenhum relatorio. Execute opcao 3."
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

install_global() {
  clear
  echo -e "${BOLD}  INSTALAR ATLAS COMO COMANDO GLOBAL${NC}"
  echo ""
  INSTALL_PATH="/usr/local/bin/atlas"
  sudo cp "$0" "$INSTALL_PATH"
  sudo chmod +x "$INSTALL_PATH"
  log "Instalado em: $INSTALL_PATH"
  grep -q "alias atlas=" "$HOME/.zshrc" 2>/dev/null || {
    echo "" >> "$HOME/.zshrc"
    echo "# Atlas Machine Control" >> "$HOME/.zshrc"
    echo "alias atlas='sudo /usr/local/bin/atlas'" >> "$HOME/.zshrc"
    log "Alias adicionado ao ~/.zshrc"
  }
  grep -q "alias atlas=" "$HOME/.bashrc" 2>/dev/null || {
    echo "" >> "$HOME/.bashrc"
    echo "# Atlas Machine Control" >> "$HOME/.bashrc"
    echo "alias atlas='sudo /usr/local/bin/atlas'" >> "$HOME/.bashrc"
    log "Alias adicionado ao ~/.bashrc"
  }
  echo ""
  echo -e "${BOLD}  Instalacao concluida!${NC}"
  echo -e "  Execute: ${CYAN}source ~/.zshrc${NC}"
  echo -e "  Depois use: ${CYAN}atlas${NC} de qualquer lugar"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

uninstall_global() {
  clear
  echo -e "${BOLD}  DESINSTALAR ATLAS${NC}"
  echo ""
  INSTALL_PATH="/usr/local/bin/atlas"
  if [ ! -f "$INSTALL_PATH" ]; then
    warn "Atlas nao instalado em $INSTALL_PATH"
    read -rp "  ENTER..."; show_menu; return
  fi
  read -rp "  Confirma desinstalacao? (s/N): " CONFIRM
  [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { warn "Cancelado."; read -rp "  ENTER..."; show_menu; return; }
  sudo rm -f "$INSTALL_PATH"
  sed -i '/# Atlas Machine Control/d; /alias atlas=/d' "$HOME/.zshrc"  2>/dev/null || true
  sed -i '/# Atlas Machine Control/d; /alias atlas=/d' "$HOME/.bashrc" 2>/dev/null || true
  log "Atlas removido."
  warn "Logs mantidos em: $LOG_DIR"
  echo ""
  read -rp "  Pressione ENTER para voltar ao menu..."
  show_menu
}

case "${1:-}" in
  --setup)          run_setup           ;;
  --optimize)       run_optimizer       ;;
  --backup)         run_backup          ;;
  --backup-dry)     run_backup_dry      ;;
  --remove-backup)  remove_backup_drive ;;
  --install-timers) install_timers      ;;
  --remove-timers)  remove_timers       ;;
  --status)         show_status         ;;
  --log-optimizer)  show_log_optimizer  ;;
  --log-backup)     show_log_backup     ;;
  --install)        install_global      ;;
  --uninstall)      uninstall_global    ;;
  *)                show_menu           ;;
esac