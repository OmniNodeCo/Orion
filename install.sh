#!/bin/bash

# ==========================================
#  Orion GUI - Linux Installer
#  Downloads pre-built binary from GitHub
#  by OmniNode
# ==========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Config
APP_NAME="OrionGUI"
GITHUB_REPO="OmniNodeCo/Orion"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO/releases"
INSTALL_DIR="$HOME/.local/share/OrionGUI"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
ARCH=$(uname -m)

# Detect pipe
IS_PIPED=false
if [ ! -t 0 ]; then
    IS_PIPED=true
fi

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║                                          ║"
    echo "║       ◉  ORION GUI INSTALLER             ║"
    echo "║           by OmniNode                    ║"
    echo "║                                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✅]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
log_error() { echo -e "${RED}[❌]${NC} $1"; }

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

safe_read() {
    local prompt="$1"
    local varname="$2"
    local default="$3"

    if [ "$IS_PIPED" = true ]; then
        eval "$varname='$default'"
        echo -e "${YELLOW}[AUTO]${NC} $prompt → $default"
    else
        read -p "$prompt" "$varname" </dev/tty
        if [ -z "${!varname}" ]; then
            eval "$varname='$default'"
        fi
    fi
}

# ==========================================
# CHECK SYSTEM
# ==========================================

check_system() {
    log_step "Checking System"

    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is for Linux only"
        exit 1
    fi
    log_success "OS: Linux $(uname -r)"
    log_success "Architecture: $ARCH"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_success "Distro: $NAME $VERSION_ID"
    fi

    # Check curl or wget
    if command -v curl &>/dev/null; then
        DOWNLOADER="curl"
        log_success "Downloader: curl"
    elif command -v wget &>/dev/null; then
        DOWNLOADER="wget"
        log_success "Downloader: wget"
    else
        log_error "curl or wget required"
        log_info "Install: sudo apt install curl"
        exit 1
    fi

    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. Installing system-wide."
        INSTALL_DIR="/opt/OrionGUI"
        BIN_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
        ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
    fi
}

# ==========================================
# FETCH RELEASES FROM GITHUB
# ==========================================

fetch_releases() {
    log_step "Fetching Available Versions"

    log_info "Checking GitHub releases..."

    local RELEASES_JSON=""
    if [ "$DOWNLOADER" = "curl" ]; then
        RELEASES_JSON=$(curl -sL "$GITHUB_API" 2>/dev/null)
    else
        RELEASES_JSON=$(wget -qO- "$GITHUB_API" 2>/dev/null)
    fi

    if [ -z "$RELEASES_JSON" ] || echo "$RELEASES_JSON" | grep -q "API rate limit"; then
        log_error "Could not fetch releases from GitHub"
        log_info "Check: https://github.com/$GITHUB_REPO/releases"
        exit 1
    fi

    # Parse releases using python (available on most Linux)
    if command -v python3 &>/dev/null; then
        AVAILABLE_VERSIONS=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        for r in releases[:10]:
            tag = r.get('tag_name', '')
            name = r.get('name', '')
            pre = r.get('prerelease', False)
            date = r.get('published_at', '')[:10]
            assets = len(r.get('assets', []))
            marker = ' (pre-release)' if pre else ''
            print(f'{tag}|{name}|{date}|{assets}{marker}')
except: pass
" 2>/dev/null)

        LATEST_VERSION=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        for r in releases:
            if not r.get('prerelease', False):
                print(r.get('tag_name', ''))
                break
except: pass
" 2>/dev/null)

        # Get download URLs for latest
        DOWNLOAD_URLS=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        for r in releases:
            if r.get('tag_name', '') == '$LATEST_VERSION' or not r.get('prerelease', False):
                for a in r.get('assets', []):
                    name = a.get('name', '')
                    url = a.get('browser_download_url', '')
                    size = a.get('size', 0)
                    size_mb = round(size / 1024 / 1024, 1)
                    print(f'{name}|{url}|{size_mb}')
                break
except: pass
" 2>/dev/null)
    else
        # Fallback: use grep
        LATEST_VERSION=$(echo "$RELEASES_JSON" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)
        DOWNLOAD_URLS=""
    fi

    if [ -z "$LATEST_VERSION" ]; then
        log_error "No releases found"
        log_info "Check: https://github.com/$GITHUB_REPO/releases"
        exit 1
    fi

    log_success "Latest version: $LATEST_VERSION"

    if [ -n "$AVAILABLE_VERSIONS" ]; then
        echo ""
        echo -e "${WHITE}Available versions:${NC}"
        local COUNT=0
        while IFS='|' read -r tag name date assets extra; do
            COUNT=$((COUNT + 1))
            echo -e "  ${CYAN}$COUNT)${NC} $tag  ($date, $assets files) $extra"
        done <<< "$AVAILABLE_VERSIONS"
        echo ""
    fi
}

# ==========================================
# SELECT VERSION
# ==========================================

select_version() {
    local SELECTED_VERSION="$LATEST_VERSION"

    if [ "$IS_PIPED" = true ]; then
        log_info "Auto-selecting latest: $LATEST_VERSION"
    elif [ -n "$1" ]; then
        SELECTED_VERSION="$1"
        log_info "Using specified version: $SELECTED_VERSION"
    else
        echo -e "${WHITE}Options:${NC}"
        echo "  1) Install latest ($LATEST_VERSION)"
        echo "  2) Choose a different version"
        echo ""

        local VERSION_CHOICE
        safe_read "Choice (1-2): " VERSION_CHOICE "1"

        if [ "$VERSION_CHOICE" = "2" ] && [ -n "$AVAILABLE_VERSIONS" ]; then
            echo ""
            echo -e "${WHITE}Available versions:${NC}"
            local VERSIONS_ARRAY=()
            local COUNT=0
            while IFS='|' read -r tag name date assets extra; do
                COUNT=$((COUNT + 1))
                VERSIONS_ARRAY+=("$tag")
                echo -e "  ${CYAN}$COUNT)${NC} $tag  ($date) $extra"
            done <<< "$AVAILABLE_VERSIONS"
            echo ""

            local VER_NUM
            safe_read "Enter number: " VER_NUM "1"

            local IDX=$((VER_NUM - 1))
            if [ $IDX -ge 0 ] && [ $IDX -lt ${#VERSIONS_ARRAY[@]} ]; then
                SELECTED_VERSION="${VERSIONS_ARRAY[$IDX]}"
            fi
        fi
    fi

    log_success "Selected version: $SELECTED_VERSION"
    INSTALL_VERSION="$SELECTED_VERSION"

    # Refresh download URLs for selected version
    if [ "$SELECTED_VERSION" != "$LATEST_VERSION" ]; then
        local RELEASES_JSON=""
        if [ "$DOWNLOADER" = "curl" ]; then
            RELEASES_JSON=$(curl -sL "$GITHUB_API" 2>/dev/null)
        else
            RELEASES_JSON=$(wget -qO- "$GITHUB_API" 2>/dev/null)
        fi

        DOWNLOAD_URLS=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        for r in releases:
            if r.get('tag_name', '') == '$SELECTED_VERSION':
                for a in r.get('assets', []):
                    name = a.get('name', '')
                    url = a.get('browser_download_url', '')
                    size = a.get('size', 0)
                    size_mb = round(size / 1024 / 1024, 1)
                    print(f'{name}|{url}|{size_mb}')
                break
except: pass
" 2>/dev/null)
    fi
}

# ==========================================
# DOWNLOAD BINARY
# ==========================================

download_binary() {
    log_step "Downloading Orion GUI $INSTALL_VERSION"

    mkdir -p "$INSTALL_DIR"

    if [ -z "$DOWNLOAD_URLS" ]; then
        log_error "No download URLs found for $INSTALL_VERSION"
        exit 1
    fi

    # Show available files
    echo -e "${WHITE}Available downloads:${NC}"
    local FILE_ARRAY=()
    local URL_ARRAY=()
    local SIZE_ARRAY=()
    local COUNT=0

    while IFS='|' read -r filename url size; do
        COUNT=$((COUNT + 1))
        FILE_ARRAY+=("$filename")
        URL_ARRAY+=("$url")
        SIZE_ARRAY+=("$size")

        local ICON="📦"
        if echo "$filename" | grep -qi "appimage"; then
            ICON="📦"
        elif echo "$filename" | grep -qi "tar.gz"; then
            ICON="📁"
        elif echo "$filename" | grep -qi "install.sh"; then
            ICON="📜"
        elif echo "$filename" | grep -qi "windows\|\.exe"; then
            ICON="🪟"
        elif echo "$filename" | grep -qi "macos\|darwin"; then
            ICON="🍎"
        fi

        # Only show Linux files
        if echo "$filename" | grep -qi "linux\|appimage\|install.sh"; then
            echo -e "  ${CYAN}$COUNT)${NC} $ICON $filename  (${size} MB)"
        fi
    done <<< "$DOWNLOAD_URLS"
    echo ""

    # Find best file for this architecture
    local DOWNLOAD_URL=""
    local DOWNLOAD_FILE=""

    # Priority: AppImage > tar.gz portable
    for priority in "AppImage" "Linux.*tar.gz" "linux.*tar.gz"; do
        while IFS='|' read -r filename url size; do
            if echo "$filename" | grep -qi "$priority"; then
                DOWNLOAD_URL="$url"
                DOWNLOAD_FILE="$filename"
                break 2
            fi
        done <<< "$DOWNLOAD_URLS"
    done

    if [ -z "$DOWNLOAD_URL" ]; then
        # Let user choose
        log_warn "Could not auto-detect Linux binary."
        echo -e "${WHITE}All available files:${NC}"
        COUNT=0
        while IFS='|' read -r filename url size; do
            COUNT=$((COUNT + 1))
            echo -e "  ${CYAN}$COUNT)${NC} $filename  (${size} MB)"
        done <<< "$DOWNLOAD_URLS"
        echo ""

        local FILE_NUM
        safe_read "Choose file number: " FILE_NUM "1"

        local IDX=$((FILE_NUM - 1))
        if [ $IDX -ge 0 ] && [ $IDX -lt ${#URL_ARRAY[@]} ]; then
            DOWNLOAD_URL="${URL_ARRAY[$IDX]}"
            DOWNLOAD_FILE="${FILE_ARRAY[$IDX]}"
        else
            log_error "Invalid choice"
            exit 1
        fi
    fi

    log_info "Downloading: $DOWNLOAD_FILE"
    log_info "URL: $DOWNLOAD_URL"

    local DOWNLOAD_PATH="$INSTALL_DIR/$DOWNLOAD_FILE"

    # Download with progress
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -L --progress-bar "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH"
    else
        wget --show-progress -q "$DOWNLOAD_URL" -O "$DOWNLOAD_PATH"
    fi

    if [ ! -f "$DOWNLOAD_PATH" ] || [ ! -s "$DOWNLOAD_PATH" ]; then
        log_error "Download failed!"
        exit 1
    fi

    local FILE_SIZE=$(du -sh "$DOWNLOAD_PATH" | cut -f1)
    log_success "Downloaded: $DOWNLOAD_FILE ($FILE_SIZE)"

    # Extract or prepare binary
    BINARY_PATH=""

    if echo "$DOWNLOAD_FILE" | grep -qi "\.tar\.gz$"; then
        log_info "Extracting archive..."
        tar -xzf "$DOWNLOAD_PATH" -C "$INSTALL_DIR"
        rm -f "$DOWNLOAD_PATH"

        # Find the binary
        BINARY_PATH=$(find "$INSTALL_DIR" -name "${APP_NAME}*" -type f -executable 2>/dev/null | head -1)

        if [ -z "$BINARY_PATH" ]; then
            BINARY_PATH=$(find "$INSTALL_DIR" -name "${APP_NAME}*" -type f 2>/dev/null | head -1)
        fi

        if [ -n "$BINARY_PATH" ]; then
            chmod +x "$BINARY_PATH"
            log_success "Extracted: $BINARY_PATH"
        else
            log_error "Could not find binary after extraction"
            log_info "Contents of $INSTALL_DIR:"
            find "$INSTALL_DIR" -type f | head -20
            exit 1
        fi

    elif echo "$DOWNLOAD_FILE" | grep -qi "\.appimage$"; then
        chmod +x "$DOWNLOAD_PATH"
        BINARY_PATH="$DOWNLOAD_PATH"
        log_success "AppImage ready: $BINARY_PATH"

    else
        chmod +x "$DOWNLOAD_PATH"
        BINARY_PATH="$DOWNLOAD_PATH"
        log_success "Binary ready: $BINARY_PATH"
    fi

    # Save binary path
    echo "$BINARY_PATH" > "$INSTALL_DIR/.binary_path"
}

# ==========================================
# OLLAMA
# ==========================================

check_ollama() {
    log_step "Checking Ollama"

    if command -v ollama &>/dev/null; then
        log_success "Ollama: $(ollama --version 2>&1 || echo 'installed')"
    else
        log_warn "Ollama not installed"
        local INSTALL_OLLAMA
        safe_read "Install Ollama? (y/n): " INSTALL_OLLAMA "y"
        if [[ "$INSTALL_OLLAMA" =~ ^[Yy]$ ]]; then
            log_info "Installing Ollama..."
            curl -fsSL https://ollama.com/install.sh | sh
            if command -v ollama &>/dev/null; then
                log_success "Ollama installed!"
            else
                log_error "Failed. Try: curl -fsSL https://ollama.com/install.sh | sh"
            fi
        fi
    fi

    if command -v ollama &>/dev/null; then
        if curl -s http://localhost:11434/api/tags &>/dev/null; then
            log_success "Ollama server running"
        else
            local START_OLLAMA
            safe_read "Start Ollama? (y/n): " START_OLLAMA "y"
            if [[ "$START_OLLAMA" =~ ^[Yy]$ ]]; then
                log_info "Starting Ollama..."
                if systemctl list-unit-files 2>/dev/null | grep -q ollama; then
                    sudo systemctl start ollama 2>/dev/null || true
                    sleep 3
                fi
                if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
                    nohup ollama serve > /dev/null 2>&1 &
                    sleep 5
                fi
                if curl -s http://localhost:11434/api/tags &>/dev/null; then
                    log_success "Ollama started"
                else
                    log_warn "Could not verify. Try: ollama serve"
                fi
            fi
        fi
    fi
}

# ==========================================
# PULL MODEL
# ==========================================

pull_orion_model() {
    log_step "Pull Orion Model"

    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        log_warn "Ollama not running. Skipping."
        return
    fi

    if curl -s http://localhost:11434/api/tags | grep -q "Orion"; then
        log_success "Orion model already installed"
        return
    fi

    if [ "$IS_PIPED" = true ]; then
        log_info "Pulling OmniNode/Orion:V1.1..."
        ollama pull OmniNode/Orion:V1.1
        return
    fi

    echo ""
    echo -e "${WHITE}Available:${NC}"
    echo "  1) OmniNode/Orion:V1.1 (latest)"
    echo "  2) OmniNode/Orion:V1.0"
    echo "  3) Skip"
    echo ""

    local MODEL_CHOICE
    safe_read "Choose (1-3): " MODEL_CHOICE "1"

    case $MODEL_CHOICE in
        1) ollama pull OmniNode/Orion:V1.1 && log_success "V1.1 downloaded!" ;;
        2) ollama pull OmniNode/Orion:V1.0 && log_success "V1.0 downloaded!" ;;
        *) log_info "Pull later: ollama pull OmniNode/Orion:V1.1" ;;
    esac
}

# ==========================================
# INSTALL SYSTEM INTEGRATION
# ==========================================

install_integration() {
    log_step "Installing System Integration"

    mkdir -p "$BIN_DIR"
    mkdir -p "$DESKTOP_DIR"
    mkdir -p "$ICON_DIR"

    # Get binary path
    local BINARY_PATH=""
    if [ -f "$INSTALL_DIR/.binary_path" ]; then
        BINARY_PATH=$(cat "$INSTALL_DIR/.binary_path")
    fi

    if [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
        BINARY_PATH=$(find "$INSTALL_DIR" -name "${APP_NAME}*" -type f -executable 2>/dev/null | head -1)
    fi

    if [ -z "$BINARY_PATH" ]; then
        log_error "Binary not found in $INSTALL_DIR"
        exit 1
    fi

    # ==========================================
    # Launcher
    # ==========================================
    cat > "$BIN_DIR/orion-gui" << LAUNCHEREOF
#!/bin/bash
# Orion GUI Launcher

BINARY="$BINARY_PATH"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "\${PURPLE}◉ Orion GUI\${NC}"

# Start Ollama
if command -v ollama &>/dev/null; then
    if ! curl -s http://localhost:11434/api/tags &>/dev/null 2>&1; then
        echo -e "\${CYAN}Starting Ollama...\${NC}"
        if systemctl is-active --quiet ollama 2>/dev/null; then
            :
        else
            nohup ollama serve > /dev/null 2>&1 &
            sleep 3
        fi
        if curl -s http://localhost:11434/api/tags &>/dev/null 2>&1; then
            echo -e "\${GREEN}✅ Ollama started\${NC}"
        else
            echo "⚠️ Ollama not responding"
        fi
    else
        echo -e "\${GREEN}✅ Ollama running\${NC}"
    fi
else
    echo "⚠️ Ollama not installed"
    echo "   Install: curl -fsSL https://ollama.com/install.sh | sh"
fi

# Open browser
if command -v xdg-open &>/dev/null; then
    (sleep 2 && xdg-open "http://localhost:5000") &
fi

echo -e "\${CYAN}🌐 http://localhost:5000\${NC}"
echo "Press Ctrl+C to stop"
echo ""

exec "\$BINARY" "\$@"
LAUNCHEREOF

    chmod +x "$BIN_DIR/orion-gui"
    log_success "Launcher: orion-gui"

    # ==========================================
    # Desktop entry
    # ==========================================
    cat > "$DESKTOP_DIR/orion-gui.desktop" << DESKTOPEOF
[Desktop Entry]
Type=Application
Name=Orion GUI
Comment=GUI for Orion AI on Ollama
GenericName=AI Chat
Exec=$BIN_DIR/orion-gui
Icon=orion-gui
Categories=Utility;Development;Science;ArtificialIntelligence;
Terminal=false
StartupNotify=true
Keywords=ai;ollama;orion;chat;llm;
DESKTOPEOF

    chmod +x "$DESKTOP_DIR/orion-gui.desktop"
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    log_success "Desktop entry created"

    # ==========================================
    # Icon
    # ==========================================
    cat > "$ICON_DIR/orion-gui.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="48" fill="#0a0a0f"/>
  <circle cx="128" cy="128" r="60" fill="none" stroke="#6c63ff" stroke-width="8"/>
  <circle cx="128" cy="128" r="20" fill="#6c63ff"/>
  <circle cx="128" cy="128" r="90" fill="none" stroke="#6c63ff" stroke-width="3" opacity="0.3"/>
</svg>
SVGEOF

    if command -v convert &>/dev/null; then
        convert "$ICON_DIR/orion-gui.svg" -resize 256x256 "$ICON_DIR/orion-gui.png" 2>/dev/null || true
    fi
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    log_success "Icon installed"

    # ==========================================
    # Uninstaller
    # ==========================================
    cat > "$BIN_DIR/orion-gui-uninstall" << UNINSTALLEOF
#!/bin/bash
echo "🗑 Uninstalling Orion GUI..."

if [ -t 0 ]; then
    read -p "Are you sure? (y/n): " CONFIRM </dev/tty
else
    CONFIRM="y"
fi

if [[ ! "\$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

systemctl --user stop orion-gui 2>/dev/null || true
systemctl --user disable orion-gui 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/orion-gui.service"
systemctl --user daemon-reload 2>/dev/null || true

rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/orion-gui"
rm -f "$BIN_DIR/orion-gui-uninstall"
rm -f "$DESKTOP_DIR/orion-gui.desktop"
rm -f "$ICON_DIR/orion-gui.svg"
rm -f "$ICON_DIR/orion-gui.png"

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "✅ Orion GUI uninstalled!"
echo "Ollama and models were NOT removed."
UNINSTALLEOF

    chmod +x "$BIN_DIR/orion-gui-uninstall"
    log_success "Uninstaller: orion-gui-uninstall"

    # ==========================================
    # Systemd service
    # ==========================================
    local SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"

    cat > "$SERVICE_DIR/orion-gui.service" << SERVICEEOF
[Unit]
Description=Orion GUI
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICEEOF

    systemctl --user daemon-reload 2>/dev/null || true
    log_success "Systemd service: orion-gui"
}

# ==========================================
# ADD TO PATH
# ==========================================

add_to_path() {
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        log_success "$BIN_DIR already in PATH"
        return
    fi

    log_info "Adding $BIN_DIR to PATH..."

    SHELL_NAME=$(basename "$SHELL")
    case $SHELL_NAME in
        bash) SHELL_RC="$HOME/.bashrc" ;;
        zsh)  SHELL_RC="$HOME/.zshrc" ;;
        fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
        *)    SHELL_RC="$HOME/.profile" ;;
    esac

    if [ -f "$SHELL_RC" ]; then
        if ! grep -q "orion-gui\|$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Orion GUI" >> "$SHELL_RC"
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            log_success "Added to $SHELL_RC"
        fi
    fi

    export PATH="$BIN_DIR:$PATH"
}

# ==========================================
# SUMMARY
# ==========================================

print_summary() {
    local BINARY_PATH=""
    if [ -f "$INSTALL_DIR/.binary_path" ]; then
        BINARY_PATH=$(cat "$INSTALL_DIR/.binary_path")
    fi

    local FINAL_SIZE=""
    if [ -n "$BINARY_PATH" ] && [ -f "$BINARY_PATH" ]; then
        FINAL_SIZE=$(du -sh "$BINARY_PATH" | cut -f1)
    fi

    echo ""
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║     ✅ ORION GUI INSTALLED!              ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}📦 Version:${NC}     $INSTALL_VERSION"
    [ -n "$FINAL_SIZE" ] && echo -e "${WHITE}📏 Size:${NC}        $FINAL_SIZE"
    echo -e "${WHITE}📁 Location:${NC}    $INSTALL_DIR"
    echo -e "${WHITE}🚀 Launch:${NC}      orion-gui"
    echo -e "${WHITE}🌐 URL:${NC}         http://localhost:5000"
    echo -e "${WHITE}🗑  Uninstall:${NC}   orion-gui-uninstall"
    echo -e "${WHITE}🔄 Update:${NC}      orion-gui-update"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}orion-gui${NC}                         Launch"
    echo -e "  ${GREEN}ollama pull OmniNode/Orion:V1.1${NC}   Pull model"
    echo -e "  ${GREEN}orion-gui-uninstall${NC}               Remove"
    echo ""
    echo -e "  ${GREEN}systemctl --user enable orion-gui${NC}  Auto-start"
    echo -e "  ${GREEN}systemctl --user start orion-gui${NC}   Start now"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Reload shell hint
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Run this to use orion-gui now:${NC}"
        echo -e "  ${GREEN}source ~/.bashrc${NC}  (or restart terminal)"
        echo ""
    fi
}

# ==========================================
# FULL INSTALL
# ==========================================

full_install() {
    check_system
    check_ollama
    fetch_releases
    select_version "$1"
    download_binary
    install_integration
    add_to_path
    pull_orion_model
    print_summary

    if [ "$IS_PIPED" = false ]; then
        local LAUNCH_NOW
        safe_read "Launch Orion GUI now? (y/n): " LAUNCH_NOW "n"
        if [[ "$LAUNCH_NOW" =~ ^[Yy]$ ]]; then
            exec "$BIN_DIR/orion-gui"
        fi
    else
        log_info "Run 'orion-gui' to start"
    fi
}

# ==========================================
# UPDATE
# ==========================================

update_install() {
    log_step "Updating Orion GUI"

    check_system
    fetch_releases

    # Check current version
    local CURRENT=""
    if [ -f "$INSTALL_DIR/.version" ]; then
        CURRENT=$(cat "$INSTALL_DIR/.version")
    fi

    if [ "$CURRENT" = "$LATEST_VERSION" ]; then
        log_success "Already on latest: $LATEST_VERSION"
        local FORCE
        safe_read "Reinstall anyway? (y/n): " FORCE "n"
        if [[ ! "$FORCE" =~ ^[Yy]$ ]]; then
            return
        fi
    else
        log_info "Current: ${CURRENT:-unknown} → Latest: $LATEST_VERSION"
    fi

    select_version
    download_binary
    install_integration

    # Save version
    echo "$INSTALL_VERSION" > "$INSTALL_DIR/.version"

    log_success "Updated to $INSTALL_VERSION!"
}

# ==========================================
# CHECK STATUS
# ==========================================

check_status() {
    log_step "System Status"

    # Version
    if [ -f "$INSTALL_DIR/.version" ]; then
        log_success "Version: $(cat "$INSTALL_DIR/.version")"
    fi

    # Binary
    if [ -f "$INSTALL_DIR/.binary_path" ]; then
        local BP=$(cat "$INSTALL_DIR/.binary_path")
        if [ -f "$BP" ]; then
            local SIZE=$(du -sh "$BP" | cut -f1)
            log_success "Binary: $BP ($SIZE)"
        else
            log_error "Binary missing: $BP"
        fi
    else
        log_error "Not installed"
    fi

    # Launcher
    if [ -f "$BIN_DIR/orion-gui" ]; then
        log_success "Launcher: $BIN_DIR/orion-gui"
    else
        log_error "Launcher: not found"
    fi

    # Desktop
    if [ -f "$DESKTOP_DIR/orion-gui.desktop" ]; then
        log_success "Desktop entry: found"
    else
        log_warn "Desktop entry: not found"
    fi

    # Ollama
    if command -v ollama &>/dev/null; then
        log_success "Ollama: $(ollama --version 2>&1 || echo 'installed')"
    else
        log_error "Ollama: not installed"
    fi

    # Ollama server
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        local MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('models',[])))" 2>/dev/null || echo "?")
        log_success "Ollama server: running ($MODELS models)"
    else
        log_error "Ollama server: not running"
    fi

    # Orion model
    if curl -s http://localhost:11434/api/tags 2>/dev/null | grep -q "Orion"; then
        log_success "Orion model: installed"
    else
        log_warn "Orion model: not found"
    fi

    echo ""
}

# ==========================================
# UNINSTALL
# ==========================================

uninstall() {
    if [ -f "$BIN_DIR/orion-gui-uninstall" ]; then
        exec "$BIN_DIR/orion-gui-uninstall"
    else
        log_error "Uninstaller not found"
        log_info "Manual: rm -rf $INSTALL_DIR && rm -f $BIN_DIR/orion-gui"
    fi
}

# ==========================================
# MENU
# ==========================================

show_menu() {
    print_banner

    if [ "$IS_PIPED" = true ]; then
        log_info "Pipe mode → auto installing latest"
        full_install
        return
    fi

    echo -e "${WHITE}Choose an option:${NC}"
    echo ""
    echo "  1) 🚀 Full Install (download + install)"
    echo "  2) 📦 Install Ollama only"
    echo "  3) 🔄 Update to latest version"
    echo "  4) 📥 Pull Orion model only"
    echo "  5) 🗑  Uninstall"
    echo "  6) 🔍 Check status"
    echo "  7) ❌ Exit"
    echo ""

    local MENU_CHOICE
    read -p "Choice (1-7): " MENU_CHOICE </dev/tty

    case $MENU_CHOICE in
        1) full_install ;;
        2) check_system && check_ollama ;;
        3) update_install ;;
        4) pull_orion_model ;;
        5) uninstall ;;
        6) check_status ;;
        7) echo "Goodbye! 👋" && exit 0 ;;
        *) log_error "Invalid choice" && show_menu ;;
    esac
}

# ==========================================
# ENTRY POINT
# ==========================================

case "${1:-}" in
    --install|-i)   full_install "$2" ;;
    --update|-u)    update_install ;;
    --uninstall|-r) uninstall ;;
    --status|-s)    check_status ;;
    --ollama)       check_system && check_ollama ;;
    --pull)         pull_orion_model ;;
    --version|-v)
        if [ -f "$INSTALL_DIR/.version" ]; then
            echo "Orion GUI $(cat "$INSTALL_DIR/.version")"
        else
            echo "Not installed"
        fi
        ;;
    --help|-h)
        echo ""
        echo "◉ Orion GUI Installer"
        echo ""
        echo "Usage: ./install.sh [option] [version]"
        echo ""
        echo "Options:"
        echo "  --install, -i [ver]  Install (latest or specific version)"
        echo "  --update, -u         Update to latest"
        echo "  --uninstall, -r      Remove"
        echo "  --status, -s         Check status"
        echo "  --version, -v        Show installed version"
        echo "  --ollama             Install Ollama"
        echo "  --pull               Pull Orion model"
        echo "  --help, -h           Show help"
        echo ""
        echo "Examples:"
        echo "  ./install.sh                    Interactive menu"
        echo "  ./install.sh --install          Install latest"
        echo "  ./install.sh --install v1.0.0   Install specific version"
        echo "  curl ... | bash                 Auto install latest"
        echo ""
        ;;
    *)
        show_menu
        ;;
esac