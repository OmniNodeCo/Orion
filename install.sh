#!/bin/bash

# ==========================================
#  Orion GUI - Linux Installer
#  Builds and installs AppImage locally
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
APP_VERSION="1.1.0"
INSTALL_DIR="$HOME/.local/share/OrionGUI"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
APPIMAGE_DIR="$HOME/.local/share/OrionGUI"
VENV_DIR="$INSTALL_DIR/venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "║      ◉  ORION GUI LOCAL INSTALLER        ║"
    echo "║            by OmniNode                   ║"
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

    ARCH=$(uname -m)
    log_success "Architecture: $ARCH"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_success "Distro: $NAME $VERSION_ID"
    fi

    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. Installing system-wide."
        INSTALL_DIR="/opt/OrionGUI"
        BIN_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
        ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
        APPIMAGE_DIR="/opt/OrionGUI"
        VENV_DIR="$INSTALL_DIR/venv"
    fi
}

# ==========================================
# DETECT PACKAGE MANAGER
# ==========================================

detect_package_manager() {
    if command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v zypper &>/dev/null; then echo "zypper"
    elif command -v apk &>/dev/null; then echo "apk"
    else echo "unknown"
    fi
}

install_package() {
    local pkg="$1"
    local PM=$(detect_package_manager)
    log_info "Installing $pkg..."

    case $PM in
        apt)    sudo apt-get update -qq 2>/dev/null; sudo apt-get install -y -qq $pkg 2>/dev/null ;;
        dnf)    sudo dnf install -y -q $pkg 2>/dev/null ;;
        yum)    sudo yum install -y -q $pkg 2>/dev/null ;;
        pacman) sudo pacman -S --noconfirm --quiet $pkg 2>/dev/null ;;
        zypper) sudo zypper install -y -q $pkg 2>/dev/null ;;
        apk)    sudo apk add --quiet $pkg 2>/dev/null ;;
        *)      log_error "Unknown package manager. Install $pkg manually."; return 1 ;;
    esac
}

# ==========================================
# CHECK DEPENDENCIES
# ==========================================

check_dependencies() {
    log_step "Checking Dependencies"

    # Python
    PYTHON_CMD=""
    if command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &>/dev/null; then
        PYTHON_CMD="python"
    else
        log_warn "Python 3 not found. Installing..."
        local PM=$(detect_package_manager)
        case $PM in
            apt) install_package "python3 python3-pip python3-venv python3-dev" ;;
            dnf|yum) install_package "python3 python3-pip python3-devel" ;;
            pacman) install_package "python python-pip" ;;
            zypper) install_package "python3 python3-pip python3-devel" ;;
            apk) install_package "python3 py3-pip python3-dev" ;;
        esac
        PYTHON_CMD="python3"
    fi

    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    log_success "Python: $PYTHON_VERSION"

    # Check Python version
    PYTHON_MAJOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.major)")
    PYTHON_MINOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.minor)")
    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
        log_error "Python 3.8+ required. Found: $PYTHON_VERSION"
        exit 1
    fi

    # pip
    if ! $PYTHON_CMD -m pip --version &>/dev/null; then
        log_warn "pip not found. Installing..."
        $PYTHON_CMD -m ensurepip --upgrade 2>/dev/null || \
        curl -sS https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD 2>/dev/null
    fi
    log_success "pip: $($PYTHON_CMD -m pip --version 2>&1 | cut -d' ' -f2)"

    # venv
    if ! $PYTHON_CMD -m venv --help &>/dev/null 2>&1; then
        log_warn "python3-venv not found. Installing..."
        local PM=$(detect_package_manager)
        case $PM in
            apt) install_package "python3-venv" ;;
        esac
    fi

    # curl
    if ! command -v curl &>/dev/null; then
        install_package "curl"
    fi
    log_success "curl: found"

    # binutils (for strip, optional)
    if ! command -v strip &>/dev/null; then
        install_package "binutils" 2>/dev/null || true
    fi
}

# ==========================================
# OLLAMA
# ==========================================

check_ollama() {
    log_step "Checking Ollama"

    if command -v ollama &>/dev/null; then
        OLLAMA_VERSION=$(ollama --version 2>&1 || echo "unknown")
        log_success "Ollama installed: $OLLAMA_VERSION"
    else
        log_warn "Ollama is not installed"
        local INSTALL_OLLAMA
        safe_read "Install Ollama now? (y/n): " INSTALL_OLLAMA "y"

        if [[ "$INSTALL_OLLAMA" =~ ^[Yy]$ ]]; then
            install_ollama
        else
            log_warn "Skipping. Install later: curl -fsSL https://ollama.com/install.sh | sh"
        fi
    fi

    if command -v ollama &>/dev/null; then
        if curl -s http://localhost:11434/api/tags &>/dev/null; then
            log_success "Ollama server running"
        else
            log_warn "Ollama server not running"
            local START_OLLAMA
            safe_read "Start Ollama server? (y/n): " START_OLLAMA "y"
            if [[ "$START_OLLAMA" =~ ^[Yy]$ ]]; then
                start_ollama
            fi
        fi
    fi
}

install_ollama() {
    log_info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    if command -v ollama &>/dev/null; then
        log_success "Ollama installed!"
    else
        log_error "Failed. Try: curl -fsSL https://ollama.com/install.sh | sh"
    fi
}

start_ollama() {
    log_info "Starting Ollama..."
    if systemctl list-unit-files 2>/dev/null | grep -q ollama; then
        sudo systemctl start ollama 2>/dev/null || true
        sudo systemctl enable ollama 2>/dev/null || true
        sleep 3
    fi

    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        nohup ollama serve > /dev/null 2>&1 &
        sleep 5
    fi

    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        log_success "Ollama server started"
    else
        log_warn "Could not verify. Try: ollama serve"
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
        log_success "Orion V1.1 downloaded!"
        return
    fi

    echo ""
    echo -e "${WHITE}Available versions:${NC}"
    echo "  1) OmniNode/Orion:V1.1 (latest)"
    echo "  2) OmniNode/Orion:V1.0"
    echo "  3) Skip"
    echo ""

    local MODEL_CHOICE
    safe_read "Choose (1-3): " MODEL_CHOICE "1"

    case $MODEL_CHOICE in
        1) ollama pull OmniNode/Orion:V1.1 && log_success "V1.1 downloaded!" ;;
        2) ollama pull OmniNode/Orion:V1.0 && log_success "V1.0 downloaded!" ;;
        *) log_info "Skipping. Pull later: ollama pull OmniNode/Orion:V1.1" ;;
    esac
}

# ==========================================
# VERIFY LOCAL FILES
# ==========================================

verify_local_files() {
    log_step "Verifying Local Files"

    local MISSING=false

    local REQUIRED_FILES=(
        "app.py"
        "templates/index.html"
        "static/style.css"
        "static/script.js"
    )

    for f in "${REQUIRED_FILES[@]}"; do
        if [ -f "$SCRIPT_DIR/$f" ]; then
            log_success "$f"
        else
            log_error "$f — MISSING"
            MISSING=true
        fi
    done

    if [ "$MISSING" = true ]; then
        log_error "Required files are missing!"
        log_info "Make sure you run this script from the Orion repo directory."
        echo ""
        echo -e "  ${GREEN}cd /path/to/Orion${NC}"
        echo -e "  ${GREEN}./install.sh${NC}"
        echo ""
        exit 1
    fi

    log_success "All required files found"
}

# ==========================================
# BUILD APPIMAGE LOCALLY
# ==========================================

build_appimage() {
    log_step "Building AppImage"

    local BUILD_DIR="$INSTALL_DIR/build"
    local APPDIR="$BUILD_DIR/AppDir"

    # Clean previous build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$APPDIR/usr/lib"

    # ==========================================
    # Step 1: Create virtual environment for build
    # ==========================================
    log_info "Creating build environment..."

    local BUILD_VENV="$BUILD_DIR/buildvenv"
    $PYTHON_CMD -m venv "$BUILD_VENV"

    "$BUILD_VENV/bin/pip" install --upgrade pip -q 2>/dev/null
    "$BUILD_VENV/bin/pip" install pyinstaller -q 2>/dev/null

    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        "$BUILD_VENV/bin/pip" install -r "$SCRIPT_DIR/requirements.txt" -q 2>/dev/null
    else
        "$BUILD_VENV/bin/pip" install flask requests pyyaml -q 2>/dev/null
    fi

    log_success "Build environment ready"

    # ==========================================
    # Step 2: Build binary with PyInstaller
    # ==========================================
    log_info "Building binary with PyInstaller..."
    log_info "This may take a few minutes..."

    cd "$SCRIPT_DIR"

    # Create config.yml if missing
    if [ ! -f "$SCRIPT_DIR/config.yml" ]; then
        create_config_file "$SCRIPT_DIR/config.yml"
    fi

    # Create install_ollama.py if missing
    if [ ! -f "$SCRIPT_DIR/install_ollama.py" ]; then
        create_install_ollama "$SCRIPT_DIR/install_ollama.py"
    fi

    "$BUILD_VENV/bin/pyinstaller" \
        --onefile \
        --name "$APP_NAME" \
        --add-data "templates:templates" \
        --add-data "static:static" \
        --add-data "config.yml:." \
        --add-data "install_ollama.py:." \
        --hidden-import flask \
        --hidden-import requests \
        --hidden-import yaml \
        --hidden-import jinja2 \
        --hidden-import markupsafe \
        --hidden-import click \
        --hidden-import blinker \
        --hidden-import itsdangerous \
        --hidden-import werkzeug \
        --clean \
        --noconfirm \
        --distpath "$BUILD_DIR/dist" \
        --workpath "$BUILD_DIR/work" \
        --specpath "$BUILD_DIR" \
        app.py 2>&1 | while IFS= read -r line; do
            # Show progress dots
            if echo "$line" | grep -q "INFO"; then
                echo -n "."
            fi
        done

    echo ""

    if [ ! -f "$BUILD_DIR/dist/$APP_NAME" ]; then
        log_error "PyInstaller build failed!"
        log_info "Check if all dependencies are installed."
        exit 1
    fi

    log_success "Binary built: $BUILD_DIR/dist/$APP_NAME"

    # Strip binary to reduce size
    if command -v strip &>/dev/null; then
        strip "$BUILD_DIR/dist/$APP_NAME" 2>/dev/null || true
        log_info "Binary stripped"
    fi

    local BINARY_SIZE=$(du -sh "$BUILD_DIR/dist/$APP_NAME" | cut -f1)
    log_info "Binary size: $BINARY_SIZE"

    # ==========================================
    # Step 3: Create AppDir structure
    # ==========================================
    log_info "Creating AppImage structure..."

    # Copy binary
    cp "$BUILD_DIR/dist/$APP_NAME" "$APPDIR/usr/bin/"
    chmod +x "$APPDIR/usr/bin/$APP_NAME"

    # Copy config files into binary directory
    cp "$SCRIPT_DIR/config.yml" "$APPDIR/usr/bin/" 2>/dev/null || true
    cp "$SCRIPT_DIR/install_ollama.py" "$APPDIR/usr/bin/" 2>/dev/null || true

    # Create AppRun
    cat > "$APPDIR/AppRun" << 'APPRUNEOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}

export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/lib64:${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"

# Auto-start Ollama if not running
if command -v ollama &>/dev/null; then
    if ! curl -s http://localhost:11434/api/tags &>/dev/null 2>&1; then
        nohup ollama serve > /dev/null 2>&1 &
        sleep 2
    fi
fi

# Open browser
if command -v xdg-open &>/dev/null; then
    (sleep 2 && xdg-open "http://localhost:5000") &
fi

exec "${HERE}/usr/bin/OrionGUI" "$@"
APPRUNEOF
    chmod +x "$APPDIR/AppRun"

    # Create .desktop file
    cat > "$APPDIR/OrionGUI.desktop" << 'DESKTOPEOF'
[Desktop Entry]
Type=Application
Name=Orion GUI
Comment=GUI for Orion AI on Ollama
Exec=OrionGUI
Icon=orion
Categories=Utility;Development;Science;ArtificialIntelligence;
Terminal=false
StartupNotify=true
Keywords=ai;ollama;orion;chat;llm;
DESKTOPEOF
    cp "$APPDIR/OrionGUI.desktop" "$APPDIR/usr/share/applications/"

    # Create icon
    cat > "$APPDIR/orion.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="48" fill="#0a0a0f"/>
  <circle cx="128" cy="128" r="60" fill="none" stroke="#6c63ff" stroke-width="8"/>
  <circle cx="128" cy="128" r="20" fill="#6c63ff"/>
  <circle cx="128" cy="128" r="90" fill="none" stroke="#6c63ff" stroke-width="3" opacity="0.3"/>
</svg>
SVGEOF

    # Convert SVG to PNG
    if command -v convert &>/dev/null; then
        convert "$APPDIR/orion.svg" -resize 256x256 "$APPDIR/orion.png" 2>/dev/null
    elif command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 256 -h 256 "$APPDIR/orion.svg" -o "$APPDIR/orion.png" 2>/dev/null
    else
        # Create a simple 1x1 PNG as fallback
        log_warn "No SVG converter found. Using SVG icon."
        cp "$APPDIR/orion.svg" "$APPDIR/orion.png" 2>/dev/null || true
    fi

    cp "$APPDIR/orion.png" "$APPDIR/.DirIcon" 2>/dev/null || true
    cp "$APPDIR/orion.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/orion.png" 2>/dev/null || true

    log_success "AppDir structure created"

    # ==========================================
    # Step 4: Build AppImage
    # ==========================================
    log_info "Packaging AppImage..."

    local APPIMAGE_FILE="$APPIMAGE_DIR/${APP_NAME}-${APP_VERSION}-${ARCH}.AppImage"
    local APPIMAGE_BUILT=false

    # Method 1: Download and use appimagetool
    log_info "Downloading appimagetool..."
    local APPIMAGETOOL="$BUILD_DIR/appimagetool"

    if [ "$ARCH" = "x86_64" ]; then
        curl -sL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -o "$APPIMAGETOOL" 2>/dev/null
    elif [ "$ARCH" = "aarch64" ]; then
        curl -sL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage" -o "$APPIMAGETOOL" 2>/dev/null
    fi

    if [ -f "$APPIMAGETOOL" ]; then
        chmod +x "$APPIMAGETOOL"

        # Try --appimage-extract-and-run first
        log_info "Building AppImage (method 1)..."
        ARCH=$ARCH "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$APPIMAGE_FILE" 2>/dev/null && {
            APPIMAGE_BUILT=true
            log_success "AppImage built (appimagetool)"
        }

        # Try extracting appimagetool
        if [ "$APPIMAGE_BUILT" = false ]; then
            log_info "Trying method 2..."
            cd "$BUILD_DIR"
            "$APPIMAGETOOL" --appimage-extract > /dev/null 2>&1 || true
            if [ -d "$BUILD_DIR/squashfs-root" ]; then
                ARCH=$ARCH "$BUILD_DIR/squashfs-root/AppRun" "$APPDIR" "$APPIMAGE_FILE" 2>/dev/null && {
                    APPIMAGE_BUILT=true
                    log_success "AppImage built (extracted tool)"
                }
            fi
            cd "$SCRIPT_DIR"
        fi
    fi

    # Method 3: Manual squashfs + runtime
    if [ "$APPIMAGE_BUILT" = false ]; then
        log_info "Trying manual method..."

        # Install squashfs-tools if needed
        if ! command -v mksquashfs &>/dev/null; then
            install_package "squashfs-tools" 2>/dev/null || true
        fi

        if command -v mksquashfs &>/dev/null; then
            # Download runtime
            local RUNTIME="$BUILD_DIR/runtime"
            if [ "$ARCH" = "x86_64" ]; then
                curl -sL "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64" -o "$RUNTIME" 2>/dev/null
            elif [ "$ARCH" = "aarch64" ]; then
                curl -sL "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-aarch64" -o "$RUNTIME" 2>/dev/null
            fi

            if [ -f "$RUNTIME" ]; then
                log_info "Creating squashfs..."
                mksquashfs "$APPDIR" "$BUILD_DIR/squashfs.img" \
                    -root-owned -noappend \
                    -comp zstd -Xcompression-level 19 2>/dev/null || \
                mksquashfs "$APPDIR" "$BUILD_DIR/squashfs.img" \
                    -root-owned -noappend 2>/dev/null

                if [ -f "$BUILD_DIR/squashfs.img" ]; then
                    cat "$RUNTIME" "$BUILD_DIR/squashfs.img" > "$APPIMAGE_FILE"
                    chmod +x "$APPIMAGE_FILE"
                    APPIMAGE_BUILT=true
                    log_success "AppImage built (manual squashfs)"
                fi
            fi
        fi
    fi

    # Method 4: Fallback — just use standalone binary
    if [ "$APPIMAGE_BUILT" = false ]; then
        log_warn "AppImage packaging failed. Using standalone binary instead."
        APPIMAGE_FILE="$APPIMAGE_DIR/$APP_NAME"
        cp "$BUILD_DIR/dist/$APP_NAME" "$APPIMAGE_FILE"
        chmod +x "$APPIMAGE_FILE"
        log_success "Standalone binary installed"
    fi

    # Show result
    if [ -f "$APPIMAGE_FILE" ]; then
        local FINAL_SIZE=$(du -sh "$APPIMAGE_FILE" | cut -f1)
        log_success "Final size: $FINAL_SIZE"
        log_success "Location: $APPIMAGE_FILE"
    fi

    # ==========================================
    # Step 5: Cleanup build files
    # ==========================================
    log_info "Cleaning up build files..."
    rm -rf "$BUILD_DIR/buildvenv"
    rm -rf "$BUILD_DIR/work"
    rm -rf "$BUILD_DIR/dist"
    rm -rf "$BUILD_DIR/AppDir"
    rm -rf "$BUILD_DIR/squashfs-root"
    rm -f "$BUILD_DIR/appimagetool"
    rm -f "$BUILD_DIR/runtime"
    rm -f "$BUILD_DIR/squashfs.img"
    rm -f "$BUILD_DIR"/*.spec
    rmdir "$BUILD_DIR" 2>/dev/null || true

    # Clean pyinstaller artifacts from source dir
    rm -rf "$SCRIPT_DIR/build" 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/__pycache__" 2>/dev/null || true
    rm -f "$SCRIPT_DIR"/*.spec 2>/dev/null || true

    log_success "Cleanup done"

    # Return the appimage path
    echo "$APPIMAGE_FILE" > /tmp/orion_appimage_path
}

# ==========================================
# CREATE HELPER FILES
# ==========================================

create_config_file() {
    local TARGET="$1"
    cat > "$TARGET" << 'CONFIGEOF'
app:
  name: Orion GUI
  version: "1.1.0"
  author: OmniNode
  port: 5000
  debug: false

ollama:
  url: http://localhost:11434
  default_model: OmniNode/Orion:V1.1
  auto_check_updates: true

models:
  available:
    - name: OmniNode/Orion:V1.1
      version: "1.1"
      description: Latest stable
      size: 4.1 GB
      latest: true
    - name: OmniNode/Orion:V1.0
      version: "1.0"
      description: Initial release
      size: 4.1 GB
      latest: false
  recommended:
    - name: mistral:7b
      description: Mistral 7B
      size: 4.1 GB
    - name: llama3:8b
      description: LLaMA 3 8B
      size: 4.7 GB
    - name: codellama:7b
      description: Code LLaMA 7B
      size: 3.8 GB

ollama_install:
  linux:
    command: curl -fsSL https://ollama.com/install.sh | sh
CONFIGEOF
}

create_install_ollama() {
    local TARGET="$1"
    cat > "$TARGET" << 'PYEOF'
#!/usr/bin/env python3
import platform, subprocess, sys, os, time
try:
    import urllib.request
except: pass

class OllamaInstaller:
    def __init__(self):
        self.system = platform.system().lower()
    def is_installed(self):
        try:
            r = subprocess.run(["ollama","--version"], capture_output=True, text=True, timeout=10)
            return r.returncode == 0
        except: return False
    def install(self):
        if self.system == "linux":
            subprocess.run(["bash","-c","curl -fsSL https://ollama.com/install.sh | sh"])
    def start(self):
        try:
            subprocess.Popen(["ollama","serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            time.sleep(5)
        except: pass

if __name__ == "__main__":
    i = OllamaInstaller()
    if not i.is_installed(): i.install()
    i.start()
PYEOF
}

# ==========================================
# INSTALL (CREATE LAUNCHER, DESKTOP, ETC)
# ==========================================

install_system_integration() {
    log_step "System Integration"

    mkdir -p "$BIN_DIR"
    mkdir -p "$DESKTOP_DIR"
    mkdir -p "$ICON_DIR"

    # Get AppImage path
    local APPIMAGE_FILE=""
    if [ -f /tmp/orion_appimage_path ]; then
        APPIMAGE_FILE=$(cat /tmp/orion_appimage_path)
        rm -f /tmp/orion_appimage_path
    else
        APPIMAGE_FILE="$APPIMAGE_DIR/$APP_NAME"
    fi

    # ==========================================
    # Launcher script
    # ==========================================
    cat > "$BIN_DIR/orion-gui" << LAUNCHEREOF
#!/bin/bash
# Orion GUI Launcher

APPIMAGE="$APPIMAGE_FILE"

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
    echo "⚠️ Ollama not installed. Install: curl -fsSL https://ollama.com/install.sh | sh"
fi

# Open browser
if command -v xdg-open &>/dev/null; then
    (sleep 2 && xdg-open "http://localhost:5000") &
fi

echo -e "\${CYAN}🌐 http://localhost:5000\${NC}"
echo "Press Ctrl+C to stop"
echo ""

# Run AppImage or binary
if [ -f "\$APPIMAGE" ]; then
    exec "\$APPIMAGE" "\$@"
else
    echo "❌ Binary not found: \$APPIMAGE"
    echo "Reinstall: ./install.sh --install"
    exit 1
fi
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

# Stop service
systemctl --user stop orion-gui 2>/dev/null || true
systemctl --user disable orion-gui 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/orion-gui.service" 2>/dev/null
systemctl --user daemon-reload 2>/dev/null || true

# Remove files
rm -rf "$INSTALL_DIR"
rm -rf "$APPIMAGE_DIR"
rm -f "$BIN_DIR/orion-gui"
rm -f "$BIN_DIR/orion-gui-uninstall"
rm -f "$DESKTOP_DIR/orion-gui.desktop"
rm -f "$ICON_DIR/orion-gui.svg"
rm -f "$ICON_DIR/orion-gui.png"

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
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
ExecStart=$APPIMAGE_FILE
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
    local APPIMAGE_FILE=""
    if [ -f /tmp/orion_appimage_path ]; then
        APPIMAGE_FILE=$(cat /tmp/orion_appimage_path)
    else
        APPIMAGE_FILE="$APPIMAGE_DIR/${APP_NAME}-${APP_VERSION}-${ARCH}.AppImage"
        if [ ! -f "$APPIMAGE_FILE" ]; then
            APPIMAGE_FILE="$APPIMAGE_DIR/$APP_NAME"
        fi
    fi

    local FINAL_SIZE=""
    if [ -f "$APPIMAGE_FILE" ]; then
        FINAL_SIZE=$(du -sh "$APPIMAGE_FILE" | cut -f1)
    fi

    echo ""
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║     ✅ ORION GUI INSTALLED!              ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}📦 AppImage:${NC}    $APPIMAGE_FILE"
    [ -n "$FINAL_SIZE" ] && echo -e "${WHITE}📏 Size:${NC}        $FINAL_SIZE"
    echo -e "${WHITE}🚀 Launch:${NC}      orion-gui"
    echo -e "${WHITE}🌐 URL:${NC}         http://localhost:5000"
    echo -e "${WHITE}🗑  Uninstall:${NC}   orion-gui-uninstall"
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
    echo ""
}

# ==========================================
# FULL INSTALL
# ==========================================

full_install() {
    check_system
    check_dependencies
    check_ollama
    verify_local_files
    build_appimage
    install_system_integration
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

    verify_local_files
    check_dependencies
    build_appimage
    install_system_integration

    log_success "Orion GUI updated!"
}

# ==========================================
# CHECK STATUS
# ==========================================

check_status() {
    log_step "System Status"

    # Python
    if command -v python3 &>/dev/null; then
        log_success "Python: $(python3 --version)"
    else
        log_error "Python: not found"
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

    # AppImage
    local FOUND_APPIMAGE=false
    for f in "$APPIMAGE_DIR/$APP_NAME"*.AppImage "$APPIMAGE_DIR/$APP_NAME"; do
        if [ -f "$f" ]; then
            local SIZE=$(du -sh "$f" | cut -f1)
            log_success "AppImage: $f ($SIZE)"
            FOUND_APPIMAGE=true
            break
        fi
    done
    if [ "$FOUND_APPIMAGE" = false ]; then
        log_error "AppImage: not found"
    fi

    # Launcher
    if [ -f "$BIN_DIR/orion-gui" ]; then
        log_success "Launcher: $BIN_DIR/orion-gui"
    else
        log_error "Launcher: not found"
    fi

    # Desktop entry
    if [ -f "$DESKTOP_DIR/orion-gui.desktop" ]; then
        log_success "Desktop entry: found"
    else
        log_warn "Desktop entry: not found"
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
        log_error "Uninstaller not found."
        log_info "Manual: rm -rf $INSTALL_DIR && rm -f $BIN_DIR/orion-gui"
    fi
}

# ==========================================
# MENU
# ==========================================

show_menu() {
    print_banner

    if [ "$IS_PIPED" = true ]; then
        log_error "Cannot install via pipe. Local files are required."
        echo ""
        echo -e "  ${GREEN}git clone https://github.com/OmniNodeCo/Orion.git${NC}"
        echo -e "  ${GREEN}cd Orion${NC}"
        echo -e "  ${GREEN}./install.sh${NC}"
        echo ""
        exit 1
    fi

    echo -e "${WHITE}Choose an option:${NC}"
    echo ""
    echo "  1) 🚀 Full Install (build AppImage + install)"
    echo "  2) 📦 Install Ollama only"
    echo "  3) 🔨 Build AppImage only"
    echo "  4) 📥 Pull Orion model only"
    echo "  5) 🔄 Update (rebuild + reinstall)"
    echo "  6) 🗑  Uninstall"
    echo "  7) 🔍 Check status"
    echo "  8) ❌ Exit"
    echo ""

    local MENU_CHOICE
    read -p "Choice (1-8): " MENU_CHOICE </dev/tty

    case $MENU_CHOICE in
        1) full_install ;;
        2) check_system && install_ollama && start_ollama ;;
        3) check_system && check_dependencies && verify_local_files && build_appimage && log_success "AppImage built!" ;;
        4) pull_orion_model ;;
        5) update_install ;;
        6) uninstall ;;
        7) check_status ;;
        8) echo "Goodbye! 👋" && exit 0 ;;
        *) log_error "Invalid choice" && show_menu ;;
    esac
}

# ==========================================
# ENTRY POINT
# ==========================================

case "${1:-}" in
    --install|-i)   full_install ;;
    --build|-b)     check_system && check_dependencies && verify_local_files && build_appimage ;;
    --update|-u)    update_install ;;
    --uninstall|-r) uninstall ;;
    --status|-s)    check_status ;;
    --ollama)       check_system && install_ollama && start_ollama ;;
    --pull)         pull_orion_model ;;
    --help|-h)
        echo ""
        echo "◉ Orion GUI Local Installer"
        echo ""
        echo "Usage: ./install.sh [option]"
        echo ""
        echo "Options:"
        echo "  --install, -i    Full install (build AppImage locally)"
        echo "  --build, -b      Build AppImage only"
        echo "  --update, -u     Rebuild and update"
        echo "  --uninstall, -r  Remove Orion GUI"
        echo "  --status, -s     Check system status"
        echo "  --ollama         Install Ollama only"
        echo "  --pull           Pull Orion model"
        echo "  --help, -h       Show this help"
        echo ""
        echo "Run from repo directory:"
        echo "  git clone https://github.com/OmniNodeCo/Orion.git"
        echo "  cd Orion"
        echo "  ./install.sh"
        echo ""
        ;;
    *)
        show_menu
        ;;
esac