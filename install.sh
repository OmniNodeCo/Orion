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
INSTALL_VERSION=""
DOWNLOAD_URLS=""
LATEST_VERSION=""
AVAILABLE_VERSIONS=""
DOWNLOADER=""

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

    # Check downloader
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

    # Check python3 (needed for JSON parsing)
    if ! command -v python3 &>/dev/null; then
        log_warn "python3 not found. Installing..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq 2>/dev/null
            sudo apt-get install -y -qq python3 2>/dev/null
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y -q python3 2>/dev/null
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm python 2>/dev/null
        elif command -v zypper &>/dev/null; then
            sudo zypper install -y python3 2>/dev/null
        elif command -v apk &>/dev/null; then
            sudo apk add python3 2>/dev/null
        fi
    fi

    if command -v python3 &>/dev/null; then
        log_success "Python: $(python3 --version 2>&1)"
    else
        log_error "python3 required for JSON parsing"
        exit 1
    fi

    # Root check
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

    if [ -z "$RELEASES_JSON" ]; then
        log_error "Could not fetch releases from GitHub"
        log_info "Check: https://github.com/$GITHUB_REPO/releases"
        exit 1
    fi

    # Check for API errors
    if echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict) and 'message' in data:
        print(data['message'])
        sys.exit(1)
except SystemExit:
    sys.exit(1)
except:
    pass
" 2>/dev/null; then
        : # OK
    else
        local ERR_MSG=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        print(data.get('message', 'Unknown error'))
except: print('Parse error')
" 2>/dev/null)
        log_error "GitHub API error: $ERR_MSG"
        exit 1
    fi

    # Parse releases
    AVAILABLE_VERSIONS=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        for r in releases[:10]:
            tag = r.get('tag_name', '')
            name = r.get('name', tag)
            pre = r.get('prerelease', False)
            draft = r.get('draft', False)
            date = r.get('published_at', '')[:10]
            assets = len(r.get('assets', []))
            marker = ''
            if pre: marker = ' [pre-release]'
            if draft: marker = ' [draft]'
            if not draft:
                print(f'{tag}|{name}|{date}|{assets}|{marker}')
except Exception as e:
    pass
" 2>/dev/null)

    # Get latest version (stable first, then pre-release)
    LATEST_VERSION=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        # Try stable first
        stable = None
        prerelease = None
        for r in releases:
            if r.get('draft', False):
                continue
            if not r.get('prerelease', False) and stable is None:
                stable = r.get('tag_name', '')
            if r.get('prerelease', False) and prerelease is None:
                prerelease = r.get('tag_name', '')

        if stable:
            print(stable)
        elif prerelease:
            print(prerelease)
        elif releases:
            print(releases[0].get('tag_name', ''))
except:
    pass
" 2>/dev/null)

    if [ -z "$LATEST_VERSION" ]; then
        log_error "No releases found"
        log_info "Check: https://github.com/$GITHUB_REPO/releases"
        exit 1
    fi

    # Check if latest is pre-release
    local IS_PRERELEASE=$(echo "$RELEASES_JSON" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    if isinstance(releases, list):
        for r in releases:
            if r.get('tag_name', '') == '$LATEST_VERSION':
                print('true' if r.get('prerelease', False) else 'false')
                break
except: pass
" 2>/dev/null)

    if [ "$IS_PRERELEASE" = "true" ]; then
        log_success "Latest version: $LATEST_VERSION (pre-release)"
    else
        log_success "Latest version: $LATEST_VERSION"
    fi

    # Show versions
    if [ -n "$AVAILABLE_VERSIONS" ]; then
        echo ""
        echo -e "${WHITE}Available versions:${NC}"
        local COUNT=0
        while IFS='|' read -r tag name date assets marker; do
            COUNT=$((COUNT + 1))
            if [ "$tag" = "$LATEST_VERSION" ]; then
                echo -e "  ${GREEN}$COUNT) $tag${NC}  ($date, $assets files)${YELLOW}$marker${NC} ← latest"
            else
                echo -e "  ${CYAN}$COUNT)${NC} $tag  ($date, $assets files)${YELLOW}$marker${NC}"
            fi
        done <<< "$AVAILABLE_VERSIONS"
        echo ""
    fi
}

# ==========================================
# GET DOWNLOAD URLS FOR A VERSION
# ==========================================

get_download_urls() {
    local VERSION="$1"

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
            if r.get('tag_name', '') == '$VERSION':
                for a in r.get('assets', []):
                    name = a.get('name', '')
                    url = a.get('browser_download_url', '')
                    size = a.get('size', 0)
                    size_mb = round(size / 1024 / 1024, 1)
                    print(f'{name}|{url}|{size_mb}')
                break
except:
    pass
" 2>/dev/null)
}

# ==========================================
# SELECT VERSION
# ==========================================

select_version() {
    INSTALL_VERSION="$LATEST_VERSION"

    # If version passed as argument
    if [ -n "$1" ]; then
        INSTALL_VERSION="$1"
        log_info "Using specified version: $INSTALL_VERSION"
        get_download_urls "$INSTALL_VERSION"
        return
    fi

    # Auto mode
    if [ "$IS_PIPED" = true ]; then
        log_info "Auto-selecting: $LATEST_VERSION"
        get_download_urls "$INSTALL_VERSION"
        return
    fi

    echo -e "${WHITE}Options:${NC}"
    echo "  1) Install latest ($LATEST_VERSION)"
    echo "  2) Choose a different version"
    echo ""

    local VERSION_CHOICE
    safe_read "Choice (1-2): " VERSION_CHOICE "1"

    if [ "$VERSION_CHOICE" = "2" ] && [ -n "$AVAILABLE_VERSIONS" ]; then
        echo ""
        echo -e "${WHITE}Select version:${NC}"
        local VERSIONS_ARRAY=()
        local COUNT=0
        while IFS='|' read -r tag name date assets marker; do
            COUNT=$((COUNT + 1))
            VERSIONS_ARRAY+=("$tag")
            echo -e "  ${CYAN}$COUNT)${NC} $tag  ($date)${YELLOW}$marker${NC}"
        done <<< "$AVAILABLE_VERSIONS"
        echo ""

        local VER_NUM
        safe_read "Enter number: " VER_NUM "1"

        local IDX=$((VER_NUM - 1))
        if [ $IDX -ge 0 ] && [ $IDX -lt ${#VERSIONS_ARRAY[@]} ]; then
            INSTALL_VERSION="${VERSIONS_ARRAY[$IDX]}"
        fi
    fi

    log_success "Selected: $INSTALL_VERSION"
    get_download_urls "$INSTALL_VERSION"
}

# ==========================================
# DOWNLOAD BINARY
# ==========================================

download_binary() {
    log_step "Downloading Orion GUI $INSTALL_VERSION"

    mkdir -p "$INSTALL_DIR"

    if [ -z "$DOWNLOAD_URLS" ]; then
        log_error "No downloads found for $INSTALL_VERSION"
        log_info "Check: https://github.com/$GITHUB_REPO/releases/tag/$INSTALL_VERSION"
        exit 1
    fi

    # Show available Linux files
    echo -e "${WHITE}Available downloads for $INSTALL_VERSION:${NC}"
    local ALL_FILES=()
    local ALL_URLS=()
    local ALL_SIZES=()
    local LINUX_COUNT=0

    while IFS='|' read -r filename url size; do
        ALL_FILES+=("$filename")
        ALL_URLS+=("$url")
        ALL_SIZES+=("$size")

        # Show Linux-relevant files
        if echo "$filename" | grep -qiE "linux|appimage|install\.sh|\.tar\.gz"; then
            LINUX_COUNT=$((LINUX_COUNT + 1))

            local ICON="📦"
            if echo "$filename" | grep -qi "appimage"; then
                ICON="📦 AppImage"
            elif echo "$filename" | grep -qi "tar.gz"; then
                ICON="📁 Portable"
            elif echo "$filename" | grep -qi "install"; then
                ICON="📜 Script"
            fi

            echo -e "  ${CYAN}${#ALL_FILES[@]})${NC} $ICON  $filename  (${size} MB)"
        fi
    done <<< "$DOWNLOAD_URLS"

    if [ $LINUX_COUNT -eq 0 ]; then
        echo -e "  ${YELLOW}No Linux-specific files found. Showing all:${NC}"
        local IDX=0
        for f in "${ALL_FILES[@]}"; do
            IDX=$((IDX + 1))
            echo -e "  ${CYAN}$IDX)${NC} $f  (${ALL_SIZES[$((IDX-1))]} MB)"
        done
    fi
    echo ""

    # Auto-select best file
    local DOWNLOAD_URL=""
    local DOWNLOAD_FILE=""

    # Priority order for auto-detection
    local PATTERNS=(
        "Linux.*\.tar\.gz"
        "linux.*\.tar\.gz"
        "Linux.*AppImage"
        "linux.*AppImage"
    )

    for pattern in "${PATTERNS[@]}"; do
        local IDX=0
        for f in "${ALL_FILES[@]}"; do
            if echo "$f" | grep -qiE "$pattern"; then
                DOWNLOAD_URL="${ALL_URLS[$IDX]}"
                DOWNLOAD_FILE="$f"
                break 2
            fi
            IDX=$((IDX + 1))
        done
    done

    # If auto-detect failed, let user choose
    if [ -z "$DOWNLOAD_URL" ]; then
        if [ "$IS_PIPED" = true ]; then
            # In pipe mode, try first file
            if [ ${#ALL_URLS[@]} -gt 0 ]; then
                DOWNLOAD_URL="${ALL_URLS[0]}"
                DOWNLOAD_FILE="${ALL_FILES[0]}"
            else
                log_error "No files to download"
                exit 1
            fi
        else
            local FILE_NUM
            safe_read "Choose file number: " FILE_NUM "1"

            local IDX=$((FILE_NUM - 1))
            if [ $IDX -ge 0 ] && [ $IDX -lt ${#ALL_URLS[@]} ]; then
                DOWNLOAD_URL="${ALL_URLS[$IDX]}"
                DOWNLOAD_FILE="${ALL_FILES[$IDX]}"
            else
                log_error "Invalid choice"
                exit 1
            fi
        fi
    fi

    log_info "Downloading: $DOWNLOAD_FILE"

    local DOWNLOAD_PATH="$INSTALL_DIR/$DOWNLOAD_FILE"

    # Download with progress
    echo ""
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -L --progress-bar "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH"
    else
        wget --show-progress -q "$DOWNLOAD_URL" -O "$DOWNLOAD_PATH"
    fi
    echo ""

    if [ ! -f "$DOWNLOAD_PATH" ] || [ ! -s "$DOWNLOAD_PATH" ]; then
        log_error "Download failed!"
        exit 1
    fi

    local FILE_SIZE=$(du -sh "$DOWNLOAD_PATH" | cut -f1)
    log_success "Downloaded: $DOWNLOAD_FILE ($FILE_SIZE)"

    # ==========================================
    # Extract or prepare binary
    # ==========================================
    BINARY_PATH=""

    if echo "$DOWNLOAD_FILE" | grep -qi "\.tar\.gz$"; then
        log_info "Extracting archive..."
        tar -xzf "$DOWNLOAD_PATH" -C "$INSTALL_DIR" 2>/dev/null
        rm -f "$DOWNLOAD_PATH"

        # Find the binary inside extracted folder
        BINARY_PATH=$(find "$INSTALL_DIR" -type f -name "${APP_NAME}*" ! -name "*.py" ! -name "*.yml" ! -name "*.md" ! -name "*.sh" ! -name "*.txt" | head -1)

        if [ -z "$BINARY_PATH" ]; then
            # Try finding any executable
            BINARY_PATH=$(find "$INSTALL_DIR" -type f -executable ! -name "*.py" ! -name "*.sh" | head -1)
        fi

        if [ -n "$BINARY_PATH" ]; then
            chmod +x "$BINARY_PATH"
            log_success "Extracted: $(basename "$BINARY_PATH")"
        else
            log_error "Could not find binary after extraction"
            log_info "Contents:"
            find "$INSTALL_DIR" -type f | head -20
            exit 1
        fi

    elif echo "$DOWNLOAD_FILE" | grep -qi "\.appimage$"; then
        chmod +x "$DOWNLOAD_PATH"
        BINARY_PATH="$DOWNLOAD_PATH"
        log_success "AppImage ready"

    else
        chmod +x "$DOWNLOAD_PATH"
        BINARY_PATH="$DOWNLOAD_PATH"
        log_success "Binary ready"
    fi

    # Save paths and version
    echo "$BINARY_PATH" > "$INSTALL_DIR/.binary_path"
    echo "$INSTALL_VERSION" > "$INSTALL_DIR/.version"

    local FINAL_SIZE=$(du -sh "$BINARY_PATH" | cut -f1)
    log_success "Binary: $(basename "$BINARY_PATH") ($FINAL_SIZE)"
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
                log_warn "Failed. Try: curl -fsSL https://ollama.com/install.sh | sh"
            fi
        else
            log_warn "Skipping. Install later: curl -fsSL https://ollama.com/install.sh | sh"
        fi
    fi

    # Check server
    if command -v ollama &>/dev/null; then
        if curl -s http://localhost:11434/api/tags &>/dev/null; then
            log_success "Ollama server running"
        else
            local START_OLLAMA
            safe_read "Start Ollama server? (y/n): " START_OLLAMA "y"
            if [[ "$START_OLLAMA" =~ ^[Yy]$ ]]; then
                log_info "Starting Ollama..."

                # Try systemd
                if systemctl list-unit-files 2>/dev/null | grep -q ollama; then
                    sudo systemctl start ollama 2>/dev/null || true
                    sudo systemctl enable ollama 2>/dev/null || true
                    sleep 3
                fi

                # Try manual
                if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
                    nohup ollama serve > /dev/null 2>&1 &
                    sleep 5
                fi

                if curl -s http://localhost:11434/api/tags &>/dev/null; then
                    log_success "Ollama started"
                else
                    log_warn "Could not verify. Try manually: ollama serve"
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

    if ! command -v ollama &>/dev/null; then
        log_warn "Ollama not installed. Skipping."
        return
    fi

    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        log_warn "Ollama not running. Skipping."
        return
    fi

    # Check if already installed
    if curl -s http://localhost:11434/api/tags | grep -q "Orion"; then
        log_success "Orion model already installed"
        return
    fi

    if [ "$IS_PIPED" = true ]; then
        log_info "Pulling OmniNode/Orion:V1.1..."
        ollama pull OmniNode/Orion:V1.1 && log_success "Orion V1.1 downloaded!" || log_warn "Pull failed"
        return
    fi

    echo ""
    echo -e "${WHITE}Available Orion versions:${NC}"
    echo "  1) OmniNode/Orion:V1.1 (latest)"
    echo "  2) OmniNode/Orion:V1.0"
    echo "  3) Skip"
    echo ""

    local MODEL_CHOICE
    safe_read "Choose (1-3): " MODEL_CHOICE "1"

    case $MODEL_CHOICE in
        1) 
            log_info "Pulling OmniNode/Orion:V1.1..."
            ollama pull OmniNode/Orion:V1.1 && log_success "V1.1 downloaded!" || log_warn "Pull failed"
            ;;
        2) 
            log_info "Pulling OmniNode/Orion:V1.0..."
            ollama pull OmniNode/Orion:V1.0 && log_success "V1.0 downloaded!" || log_warn "Pull failed"
            ;;
        *) 
            log_info "Pull later: ollama pull OmniNode/Orion:V1.1"
            ;;
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
        BINARY_PATH=$(find "$INSTALL_DIR" -type f -name "${APP_NAME}*" -executable ! -name "*.py" ! -name "*.sh" 2>/dev/null | head -1)
    fi

    if [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
        log_error "Binary not found in $INSTALL_DIR"
        log_info "Contents:"
        find "$INSTALL_DIR" -type f | head -20
        exit 1
    fi

    log_info "Binary: $BINARY_PATH"

    # ==========================================
    # Launcher
    # ==========================================
    cat > "$BIN_DIR/orion-gui" << LAUNCHEREOF
#!/bin/bash
# Orion GUI Launcher - by OmniNode

BINARY="$BINARY_PATH"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "\${PURPLE}◉ Orion GUI\${NC}"

# Start Ollama if needed
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
    (sleep 2 && xdg-open "http://localhost:5000") &>/dev/null 2>&1 &
fi

echo -e "\${CYAN}🌐 http://localhost:5000\${NC}"
echo "Press Ctrl+C to stop"
echo ""

if [ -f "\$BINARY" ]; then
    exec "\$BINARY" "\$@"
else
    echo "❌ Binary not found: \$BINARY"
    echo "Reinstall: curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash"
    exit 1
fi
LAUNCHEREOF

    chmod +x "$BIN_DIR/orion-gui"
    log_success "Launcher: orion-gui"

    # ==========================================
    # Update command
    # ==========================================
    cat > "$BIN_DIR/orion-gui-update" << UPDATEEOF
#!/bin/bash
# Orion GUI Updater
echo "🔄 Checking for updates..."

SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh"
TEMP_SCRIPT=\$(mktemp)

if curl -sL "\$SCRIPT_URL" -o "\$TEMP_SCRIPT" 2>/dev/null; then
    chmod +x "\$TEMP_SCRIPT"
    exec bash "\$TEMP_SCRIPT" --update
else
    echo "❌ Could not download updater"
    echo "Manual: curl -fsSL \$SCRIPT_URL | bash"
fi
UPDATEEOF

    chmod +x "$BIN_DIR/orion-gui-update"
    log_success "Updater: orion-gui-update"

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

    # Try to convert SVG to PNG
    if command -v convert &>/dev/null; then
        convert "$ICON_DIR/orion-gui.svg" -resize 256x256 "$ICON_DIR/orion-gui.png" 2>/dev/null || true
    elif command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 256 -h 256 "$ICON_DIR/orion-gui.svg" -o "$ICON_DIR/orion-gui.png" 2>/dev/null || true
    fi

    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    log_success "Icon installed"

    # ==========================================
    # Uninstaller
    # ==========================================
    cat > "$BIN_DIR/orion-gui-uninstall" << UNINSTALLEOF
#!/bin/bash
echo ""
echo "🗑 Uninstalling Orion GUI..."
echo ""

if [ -t 0 ]; then
    read -p "Are you sure? (y/n): " CONFIRM </dev/tty
else
    CONFIRM="y"
fi

if [[ ! "\$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# Stop service
systemctl --user stop orion-gui 2>/dev/null || true
systemctl --user disable orion-gui 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/orion-gui.service" 2>/dev/null
systemctl --user daemon-reload 2>/dev/null || true

# Remove files
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/orion-gui"
rm -f "$BIN_DIR/orion-gui-update"
rm -f "$BIN_DIR/orion-gui-uninstall"
rm -f "$DESKTOP_DIR/orion-gui.desktop"
rm -f "$ICON_DIR/orion-gui.svg"
rm -f "$ICON_DIR/orion-gui.png"

# Update caches
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "✅ Orion GUI uninstalled!"
echo ""
echo "Note: Ollama and models were NOT removed."
echo "  Remove Ollama: sudo rm /usr/local/bin/ollama"
echo "  Remove models: rm -rf ~/.ollama"
echo ""
UNINSTALLEOF

    chmod +x "$BIN_DIR/orion-gui-uninstall"
    log_success "Uninstaller: orion-gui-uninstall"

    # ==========================================
    # Systemd service
    # ==========================================
    if [ "$EUID" -eq 0 ]; then
        local SERVICE_FILE="/etc/systemd/system/orion-gui.service"
        cat > "$SERVICE_FILE" << SERVICEEOF
[Unit]
Description=Orion GUI
After=network.target ollama.service

[Service]
Type=simple
ExecStart=$BINARY_PATH
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF
        systemctl daemon-reload 2>/dev/null || true
    else
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
    fi

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
        else
            log_success "Already in $SHELL_RC"
        fi
    fi

    export PATH="$BIN_DIR:$PATH"
}

# ==========================================
# SUMMARY
# ==========================================

print_summary() {
    local BINARY_PATH=""
    local VERSION=""
    local FINAL_SIZE=""

    if [ -f "$INSTALL_DIR/.binary_path" ]; then
        BINARY_PATH=$(cat "$INSTALL_DIR/.binary_path")
    fi
    if [ -f "$INSTALL_DIR/.version" ]; then
        VERSION=$(cat "$INSTALL_DIR/.version")
    fi
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
    [ -n "$VERSION" ]    && echo -e "${WHITE}📦 Version:${NC}     $VERSION"
    [ -n "$FINAL_SIZE" ] && echo -e "${WHITE}📏 Size:${NC}        $FINAL_SIZE"
    echo -e "${WHITE}📁 Location:${NC}    $INSTALL_DIR"
    echo -e "${WHITE}🚀 Launch:${NC}      orion-gui"
    echo -e "${WHITE}🌐 URL:${NC}         http://localhost:5000"
    echo -e "${WHITE}🔄 Update:${NC}      orion-gui-update"
    echo -e "${WHITE}🗑  Uninstall:${NC}   orion-gui-uninstall"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}orion-gui${NC}                         Launch GUI"
    echo -e "  ${GREEN}orion-gui-update${NC}                  Check for updates"
    echo -e "  ${GREEN}ollama pull OmniNode/Orion:V1.1${NC}   Pull model"
    echo -e "  ${GREEN}orion-gui-uninstall${NC}               Remove"
    echo ""

    if [ "$EUID" -eq 0 ]; then
        echo -e "  ${GREEN}sudo systemctl enable orion-gui${NC}   Auto-start"
        echo -e "  ${GREEN}sudo systemctl start orion-gui${NC}    Start now"
    else
        echo -e "  ${GREEN}systemctl --user enable orion-gui${NC}  Auto-start"
        echo -e "  ${GREEN}systemctl --user start orion-gui${NC}   Start now"
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Shell reload hint
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  To use orion-gui right now, run:${NC}"
        echo -e "  ${GREEN}source ~/${SHELL_RC##*/}${NC}  or restart your terminal"
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
        log_info "Run 'orion-gui' to start (restart terminal first)"
    fi
}

# ==========================================
# UPDATE
# ==========================================

update_install() {
    check_system

    # Check current
    local CURRENT=""
    if [ -f "$INSTALL_DIR/.version" ]; then
        CURRENT=$(cat "$INSTALL_DIR/.version")
        log_info "Current version: $CURRENT"
    else
        log_warn "No version info found"
    fi

    fetch_releases

    if [ -n "$CURRENT" ] && [ "$CURRENT" = "$LATEST_VERSION" ]; then
        log_success "Already on latest: $LATEST_VERSION"

        if [ "$IS_PIPED" = true ]; then
            log_info "No update needed"
            return
        fi

        local FORCE
        safe_read "Reinstall anyway? (y/n): " FORCE "n"
        if [[ ! "$FORCE" =~ ^[Yy]$ ]]; then
            return
        fi
    else
        if [ -n "$CURRENT" ]; then
            log_info "Updating: $CURRENT → $LATEST_VERSION"
        fi
    fi

    select_version "$1"

    # Backup old binary path
    local OLD_BINARY=""
    if [ -f "$INSTALL_DIR/.binary_path" ]; then
        OLD_BINARY=$(cat "$INSTALL_DIR/.binary_path")
    fi

    download_binary
    install_integration
    
    # Clean old binary if path changed
    if [ -n "$OLD_BINARY" ] && [ -f "$INSTALL_DIR/.binary_path" ]; then
        local NEW_BINARY=$(cat "$INSTALL_DIR/.binary_path")
        if [ "$OLD_BINARY" != "$NEW_BINARY" ] && [ -f "$OLD_BINARY" ]; then
            rm -f "$OLD_BINARY" 2>/dev/null || true
        fi
    fi

    log_success "Updated to $INSTALL_VERSION!"
    print_summary
}

# ==========================================
# CHECK STATUS
# ==========================================

check_status() {
    log_step "System Status"

    # Installed version
    if [ -f "$INSTALL_DIR/.version" ]; then
        log_success "Installed: $(cat "$INSTALL_DIR/.version")"
    else
        log_error "Orion GUI: not installed"
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
        local MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data.get('models', [])))
except: print('?')
" 2>/dev/null)
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

    # Check for updates
    echo ""
    log_info "Checking for updates..."
    local CURRENT=""
    if [ -f "$INSTALL_DIR/.version" ]; then
        CURRENT=$(cat "$INSTALL_DIR/.version")
    fi

    local REMOTE_LATEST=""
    if [ -n "$DOWNLOADER" ]; then
        :
    elif command -v curl &>/dev/null; then
        DOWNLOADER="curl"
    elif command -v wget &>/dev/null; then
        DOWNLOADER="wget"
    fi

    if [ -n "$DOWNLOADER" ]; then
        local API_RESPONSE=""
        if [ "$DOWNLOADER" = "curl" ]; then
            API_RESPONSE=$(curl -sL "$GITHUB_API/latest" 2>/dev/null || curl -sL "$GITHUB_API" 2>/dev/null)
        else
            API_RESPONSE=$(wget -qO- "$GITHUB_API/latest" 2>/dev/null || wget -qO- "$GITHUB_API" 2>/dev/null)
        fi

        REMOTE_LATEST=$(echo "$API_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        print(data.get('tag_name', ''))
    elif isinstance(data, list) and data:
        for r in data:
            if not r.get('draft', False):
                print(r.get('tag_name', ''))
                break
except: pass
" 2>/dev/null)
    fi

    if [ -n "$REMOTE_LATEST" ] && [ -n "$CURRENT" ]; then
        if [ "$CURRENT" = "$REMOTE_LATEST" ]; then
            log_success "Up to date ($CURRENT)"
        else
            log_warn "Update available: $CURRENT → $REMOTE_LATEST"
            log_info "Run: orion-gui-update"
        fi
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
        log_info "Manual removal:"
        echo "  rm -rf $INSTALL_DIR"
        echo "  rm -f $BIN_DIR/orion-gui"
        echo "  rm -f $BIN_DIR/orion-gui-update"
        echo "  rm -f $BIN_DIR/orion-gui-uninstall"
        echo "  rm -f $DESKTOP_DIR/orion-gui.desktop"
    fi
}

# ==========================================
# MENU
# ==========================================

show_menu() {
    print_banner

    if [ "$IS_PIPED" = true ]; then
        log_info "Pipe mode → installing latest automatically"
        echo ""
        full_install
        return
    fi

    echo -e "${WHITE}Choose an option:${NC}"
    echo ""
    echo "  1) 🚀 Full Install (download latest)"
    echo "  2) 📦 Install Ollama only"
    echo "  3) 🔄 Update to latest version"
    echo "  4) 📥 Pull Orion model only"
    echo "  5) 🔍 Check status"
    echo "  6) 🗑  Uninstall"
    echo "  7) ❌ Exit"
    echo ""

    local MENU_CHOICE
    read -p "Choice (1-7): " MENU_CHOICE </dev/tty

    case $MENU_CHOICE in
        1) full_install ;;
        2) check_system && check_ollama ;;
        3) update_install ;;
        4) pull_orion_model ;;
        5) check_status ;;
        6) uninstall ;;
        7) echo "Goodbye! 👋" && exit 0 ;;
        *) log_error "Invalid choice" && show_menu ;;
    esac
}

# ==========================================
# ENTRY POINT
# ==========================================

case "${1:-}" in
    --install|-i)   full_install "$2" ;;
    --update|-u)    update_install "$2" ;;
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
        echo "◉ Orion GUI Installer - by OmniNode"
        echo ""
        echo "Usage: ./install.sh [option] [version]"
        echo ""
        echo "Options:"
        echo "  --install, -i [ver]  Install (latest or specific version)"
        echo "  --update, -u         Update to latest version"
        echo "  --uninstall, -r      Remove Orion GUI"
        echo "  --status, -s         Check status + update check"
        echo "  --version, -v        Show installed version"
        echo "  --ollama             Install Ollama only"
        echo "  --pull               Pull Orion model"
        echo "  --help, -h           Show this help"
        echo ""
        echo "Examples:"
        echo "  ./install.sh                      Interactive menu"
        echo "  ./install.sh --install            Install latest"
        echo "  ./install.sh --install 1.0-beta   Install specific version"
        echo "  ./install.sh --update             Update to latest"
        echo "  ./install.sh --status             Check everything"
        echo "  curl ... | bash                   Auto install latest"
        echo ""
        echo "After install:"
        echo "  orion-gui                         Launch GUI"
        echo "  orion-gui-update                  Check for updates"
        echo "  orion-gui-uninstall               Remove GUI"
        echo ""
        ;;
    *)
        show_menu
        ;;
esac