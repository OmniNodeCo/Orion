#!/bin/bash

# ==========================================
#  Orion GUI - Linux Installer
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
NC='\033[0m' # No Color

# Config
APP_NAME="OrionGUI"
APP_VERSION="1.1.0"
INSTALL_DIR="$HOME/.local/share/OrionGUI"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
VENV_DIR="$INSTALL_DIR/venv"
REPO_URL="https://github.com/OmniNode/Orion"
RAW_URL="https://raw.githubusercontent.com/OmniNode/Orion/main"

# ==========================================
# FUNCTIONS
# ==========================================

print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║                                          ║"
    echo "║          ◉  ORION GUI INSTALLER          ║"
    echo "║             by OmniNode                  ║"
    echo "║                                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠️]${NC} $1"
}

log_error() {
    echo -e "${RED}[❌]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ==========================================
# CHECK SYSTEM
# ==========================================

check_system() {
    log_step "Checking System"

    # Check OS
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is for Linux only"
        log_info "For macOS: brew install ollama"
        log_info "For Windows: download from ollama.com"
        exit 1
    fi
    log_success "OS: Linux $(uname -r)"

    # Check arch
    ARCH=$(uname -m)
    log_success "Architecture: $ARCH"

    # Check distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_success "Distro: $NAME $VERSION_ID"
    fi

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. Will install system-wide."
        INSTALL_DIR="/opt/OrionGUI"
        BIN_DIR="/usr/local/bin"
        DESKTOP_DIR="/usr/share/applications"
        ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
        VENV_DIR="$INSTALL_DIR/venv"
    fi
}

# ==========================================
# CHECK DEPENDENCIES
# ==========================================

check_dependencies() {
    log_step "Checking Dependencies"

    # Check Python
    PYTHON_CMD=""
    if command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
        log_success "Python: $PYTHON_VERSION"
    elif command -v python &>/dev/null; then
        PYTHON_CMD="python"
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
        log_success "Python: $PYTHON_VERSION"
    else
        log_error "Python 3 is not installed"
        log_info "Installing Python 3..."
        install_python
    fi

    # Check Python version >= 3.8
    if [ -n "$PYTHON_CMD" ]; then
        PYTHON_MAJOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.major)")
        PYTHON_MINOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.minor)")

        if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
            log_error "Python 3.8+ required. Found: $PYTHON_VERSION"
            install_python
        fi
    fi

    # Check pip
    if ! $PYTHON_CMD -m pip --version &>/dev/null; then
        log_warn "pip not found. Installing..."
        install_pip
    else
        log_success "pip: $($PYTHON_CMD -m pip --version | cut -d' ' -f2)"
    fi

    # Check git
    if command -v git &>/dev/null; then
        log_success "git: $(git --version | cut -d' ' -f3)"
    else
        log_warn "git not found. Installing..."
        install_git
    fi

    # Check curl
    if command -v curl &>/dev/null; then
        log_success "curl: found"
    else
        log_warn "curl not found. Installing..."
        install_curl
    fi
}

# ==========================================
# INSTALL SYSTEM PACKAGES
# ==========================================

detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

install_package() {
    local pkg=$1
    local PM=$(detect_package_manager)

    log_info "Installing $pkg using $PM..."

    case $PM in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y -qq "$pkg"
            ;;
        dnf)
            sudo dnf install -y -q "$pkg"
            ;;
        yum)
            sudo yum install -y -q "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm --quiet "$pkg"
            ;;
        zypper)
            sudo zypper install -y -q "$pkg"
            ;;
        apk)
            sudo apk add --quiet "$pkg"
            ;;
        *)
            log_error "Unknown package manager. Please install $pkg manually."
            exit 1
            ;;
    esac
}

install_python() {
    local PM=$(detect_package_manager)
    case $PM in
        apt) install_package "python3 python3-pip python3-venv" ;;
        dnf) install_package "python3 python3-pip" ;;
        yum) install_package "python3 python3-pip" ;;
        pacman) install_package "python python-pip" ;;
        zypper) install_package "python3 python3-pip" ;;
        apk) install_package "python3 py3-pip" ;;
    esac

    PYTHON_CMD="python3"
    log_success "Python installed"
}

install_pip() {
    $PYTHON_CMD -m ensurepip --upgrade 2>/dev/null || true
    if ! $PYTHON_CMD -m pip --version &>/dev/null; then
        curl -sS https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
    fi
    log_success "pip installed"
}

install_git() {
    install_package "git"
    log_success "git installed"
}

install_curl() {
    install_package "curl"
    log_success "curl installed"
}

# ==========================================
# CHECK / INSTALL OLLAMA
# ==========================================

check_ollama() {
    log_step "Checking Ollama"

    if command -v ollama &>/dev/null; then
        OLLAMA_VERSION=$(ollama --version 2>&1 || echo "unknown")
        log_success "Ollama installed: $OLLAMA_VERSION"
    else
        log_warn "Ollama is not installed"
        echo ""
        echo -e "${YELLOW}Ollama is required to run Orion GUI.${NC}"
        echo ""
        read -p "Install Ollama now? (y/n): " INSTALL_OLLAMA

        if [[ "$INSTALL_OLLAMA" =~ ^[Yy]$ ]]; then
            install_ollama
        else
            log_warn "Skipping Ollama installation"
            log_info "Install later: curl -fsSL https://ollama.com/install.sh | sh"
        fi
    fi

    # Check if Ollama is running
    if command -v ollama &>/dev/null; then
        if curl -s http://localhost:11434/api/tags &>/dev/null; then
            log_success "Ollama server is running"
        else
            log_warn "Ollama server is not running"
            read -p "Start Ollama server? (y/n): " START_OLLAMA
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
        log_success "Ollama installed successfully!"
    else
        log_error "Ollama installation failed"
        log_info "Try manually: curl -fsSL https://ollama.com/install.sh | sh"
    fi
}

start_ollama() {
    log_info "Starting Ollama server..."

    # Check if systemd service exists
    if systemctl list-unit-files | grep -q ollama; then
        sudo systemctl start ollama 2>/dev/null || true
        sudo systemctl enable ollama 2>/dev/null || true
        sleep 3
        if curl -s http://localhost:11434/api/tags &>/dev/null; then
            log_success "Ollama server started (systemd)"
            return
        fi
    fi

    # Fallback: start manually
    nohup ollama serve > /dev/null 2>&1 &
    sleep 5

    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        log_success "Ollama server started"
    else
        log_warn "Could not verify Ollama server"
        log_info "Try manually: ollama serve"
    fi
}

# ==========================================
# PULL ORION MODEL
# ==========================================

pull_orion_model() {
    log_step "Pull Orion Model"

    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        log_warn "Ollama server not running. Skipping model pull."
        return
    fi

    # Check if already pulled
    if curl -s http://localhost:11434/api/tags | grep -q "OmniNode/Orion"; then
        log_success "Orion model already installed"
        return
    fi

    echo ""
    echo -e "${WHITE}Available Orion versions:${NC}"
    echo "  1) OmniNode/Orion:V1.1 (latest)"
    echo "  2) OmniNode/Orion:V1.0"
    echo "  3) Skip"
    echo ""
    read -p "Choose version (1-3): " MODEL_CHOICE

    case $MODEL_CHOICE in
        1)
            log_info "Pulling OmniNode/Orion:V1.1..."
            ollama pull OmniNode/Orion:V1.1
            log_success "Orion V1.1 downloaded!"
            ;;
        2)
            log_info "Pulling OmniNode/Orion:V1.0..."
            ollama pull OmniNode/Orion:V1.0
            log_success "Orion V1.0 downloaded!"
            ;;
        *)
            log_info "Skipping model pull"
            log_info "Pull later: ollama pull OmniNode/Orion:V1.1"
            ;;
    esac
}

# ==========================================
# INSTALL ORION GUI
# ==========================================

install_orion_gui() {
    log_step "Installing Orion GUI"

    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$DESKTOP_DIR"
    mkdir -p "$ICON_DIR"

    # Clone or download repo
    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull origin main 2>/dev/null || true
    elif command -v git &>/dev/null; then
        log_info "Cloning repository..."
        git clone "$REPO_URL.git" "$INSTALL_DIR" 2>/dev/null || {
            log_warn "Git clone failed. Downloading files directly..."
            download_files
        }
    else
        log_info "Downloading files..."
        download_files
    fi

    cd "$INSTALL_DIR"

    # Create virtual environment
    log_info "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR" 2>/dev/null || {
        log_warn "venv failed, trying without..."
        VENV_DIR=""
    }

    # Install Python packages
    if [ -n "$VENV_DIR" ] && [ -d "$VENV_DIR" ]; then
        log_info "Installing Python packages in venv..."
        "$VENV_DIR/bin/pip" install --upgrade pip -q
        "$VENV_DIR/bin/pip" install flask requests pyyaml -q
        PYTHON_RUN="$VENV_DIR/bin/python"
    else
        log_info "Installing Python packages globally..."
        $PYTHON_CMD -m pip install --user flask requests pyyaml -q
        PYTHON_RUN="$PYTHON_CMD"
    fi

    log_success "Python packages installed"

    # Create config.yml if missing
    if [ ! -f "$INSTALL_DIR/config.yml" ]; then
        create_config
    fi

    # Create launcher script
    create_launcher

    # Create desktop entry
    create_desktop_entry

    # Create icon
    create_icon

    # Create uninstaller
    create_uninstaller

    # Create systemd service (optional)
    create_systemd_service

    log_success "Orion GUI installed to $INSTALL_DIR"
}

download_files() {
    mkdir -p "$INSTALL_DIR/templates"
    mkdir -p "$INSTALL_DIR/static"

    FILES=(
        "app.py"
        "requirements.txt"
        "templates/index.html"
        "static/style.css"
        "static/script.js"
    )

    for file in "${FILES[@]}"; do
        log_info "Downloading $file..."
        curl -sL "$RAW_URL/$file" -o "$INSTALL_DIR/$file" 2>/dev/null || {
            log_warn "Failed to download $file"
        }
    done
}

create_config() {
    cat > "$INSTALL_DIR/config.yml" << 'CONFIGEOF'
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

    log_success "config.yml created"
}

create_launcher() {
    if [ -n "$VENV_DIR" ] && [ -d "$VENV_DIR" ]; then
        PYTHON_PATH="$VENV_DIR/bin/python"
    else
        PYTHON_PATH="$PYTHON_CMD"
    fi

    cat > "$BIN_DIR/orion-gui" << LAUNCHEREOF
#!/bin/bash
# Orion GUI Launcher
# by OmniNode

APP_DIR="$INSTALL_DIR"
PYTHON="$PYTHON_PATH"
PORT=5000

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "\${PURPLE}"
echo "◉ Orion GUI"
echo -e "\${NC}"

# Check Ollama
if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo -e "\${CYAN}Starting Ollama server...\${NC}"
    
    if systemctl is-active --quiet ollama 2>/dev/null; then
        : # already running via systemd
    else
        nohup ollama serve > /dev/null 2>&1 &
        sleep 3
    fi
    
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        echo -e "\${GREEN}✅ Ollama server started\${NC}"
    else
        echo "⚠️ Ollama not running. Some features may not work."
        echo "   Install: curl -fsSL https://ollama.com/install.sh | sh"
    fi
else
    echo -e "\${GREEN}✅ Ollama server running\${NC}"
fi

# Open browser
if command -v xdg-open &>/dev/null; then
    (sleep 2 && xdg-open "http://localhost:\$PORT") &
elif command -v open &>/dev/null; then
    (sleep 2 && open "http://localhost:\$PORT") &
fi

echo -e "\${CYAN}🌐 http://localhost:\$PORT\${NC}"
echo "Press Ctrl+C to stop"
echo ""

# Run app
cd "\$APP_DIR"
exec \$PYTHON app.py
LAUNCHEREOF

    chmod +x "$BIN_DIR/orion-gui"
    log_success "Launcher created: $BIN_DIR/orion-gui"
}

create_desktop_entry() {
    cat > "$DESKTOP_DIR/orion-gui.desktop" << DESKTOPEOF
[Desktop Entry]
Type=Application
Name=Orion GUI
Comment=GUI for Orion AI on Ollama
GenericName=AI Chat
Exec=$BIN_DIR/orion-gui
Icon=orion-gui
Categories=Utility;Development;Science;ArtificialIntelligence;
Terminal=true
StartupNotify=true
Keywords=ai;ollama;orion;chat;llm;assistant;
DESKTOPEOF

    chmod +x "$DESKTOP_DIR/orion-gui.desktop"

    # Update desktop database
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi

    log_success "Desktop entry created"
}

create_icon() {
    # Create SVG icon
    cat > "$ICON_DIR/orion-gui.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="48" fill="#0a0a0f"/>
  <circle cx="128" cy="128" r="60" fill="none" stroke="#6c63ff" stroke-width="8"/>
  <circle cx="128" cy="128" r="20" fill="#6c63ff"/>
  <circle cx="128" cy="128" r="90" fill="none" stroke="#6c63ff" stroke-width="3" opacity="0.3"/>
</svg>
SVGEOF

    # Convert to PNG if imagemagick is available
    if command -v convert &>/dev/null; then
        convert "$ICON_DIR/orion-gui.svg" -resize 256x256 "$ICON_DIR/orion-gui.png" 2>/dev/null || true
    fi

    # Update icon cache
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi

    log_success "Icon created"
}

create_uninstaller() {
    cat > "$BIN_DIR/orion-gui-uninstall" << UNINSTALLEOF
#!/bin/bash
# Orion GUI Uninstaller

echo "🗑 Uninstalling Orion GUI..."
echo ""

read -p "Are you sure? (y/n): " CONFIRM
if [[ ! "\$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Stop service
if systemctl is-active --quiet orion-gui 2>/dev/null; then
    sudo systemctl stop orion-gui
    sudo systemctl disable orion-gui
    sudo rm -f /etc/systemd/system/orion-gui.service
    sudo systemctl daemon-reload
fi

# Remove files
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/orion-gui"
rm -f "$BIN_DIR/orion-gui-uninstall"
rm -f "$DESKTOP_DIR/orion-gui.desktop"
rm -f "$ICON_DIR/orion-gui.svg"
rm -f "$ICON_DIR/orion-gui.png"

# Update caches
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "✅ Orion GUI uninstalled successfully!"
echo ""
echo "Note: Ollama and models were NOT removed."
echo "To remove Ollama: sudo rm /usr/local/bin/ollama"
echo "To remove models: rm -rf ~/.ollama"
UNINSTALLEOF

    chmod +x "$BIN_DIR/orion-gui-uninstall"
    log_success "Uninstaller created: orion-gui-uninstall"
}

create_systemd_service() {
    # Only create if running as root or user has systemd user dir
    if [ "$EUID" -eq 0 ]; then
        SERVICE_FILE="/etc/systemd/system/orion-gui.service"
        SYSTEMCTL_CMD="sudo systemctl"
    else
        SERVICE_DIR="$HOME/.config/systemd/user"
        mkdir -p "$SERVICE_DIR"
        SERVICE_FILE="$SERVICE_DIR/orion-gui.service"
        SYSTEMCTL_CMD="systemctl --user"
    fi

    if [ -n "$VENV_DIR" ] && [ -d "$VENV_DIR" ]; then
        EXEC_START="$VENV_DIR/bin/python $INSTALL_DIR/app.py"
    else
        EXEC_START="$PYTHON_CMD $INSTALL_DIR/app.py"
    fi

    cat > "$SERVICE_FILE" << SERVICEEOF
[Unit]
Description=Orion GUI - AI Chat Interface
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$EXEC_START
Restart=on-failure
RestartSec=5
Environment=FLASK_ENV=production

[Install]
WantedBy=default.target
SERVICEEOF

    log_success "Systemd service created: orion-gui.service"
    log_info "Enable with: $SYSTEMCTL_CMD enable orion-gui"
    log_info "Start with:  $SYSTEMCTL_CMD start orion-gui"
}

# ==========================================
# ADD TO PATH
# ==========================================

add_to_path() {
    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        log_info "Adding $BIN_DIR to PATH..."

        # Detect shell
        SHELL_NAME=$(basename "$SHELL")
        case $SHELL_NAME in
            bash)
                SHELL_RC="$HOME/.bashrc"
                ;;
            zsh)
                SHELL_RC="$HOME/.zshrc"
                ;;
            fish)
                SHELL_RC="$HOME/.config/fish/config.fish"
                ;;
            *)
                SHELL_RC="$HOME/.profile"
                ;;
        esac

        if [ -f "$SHELL_RC" ]; then
            if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
                echo "" >> "$SHELL_RC"
                echo "# Orion GUI" >> "$SHELL_RC"
                echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
                log_success "Added to $SHELL_RC"
            fi
        fi

        # Also add to current session
        export PATH="$BIN_DIR:$PATH"
    else
        log_success "$BIN_DIR already in PATH"
    fi
}

# ==========================================
# PRINT SUMMARY
# ==========================================

print_summary() {
    echo ""
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║                                          ║"
    echo "║     ✅ ORION GUI INSTALLED!              ║"
    echo "║                                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}📁 Install location:${NC}  $INSTALL_DIR"
    echo -e "${WHITE}🚀 Launch command:${NC}    orion-gui"
    echo -e "${WHITE}🌐 Web interface:${NC}     http://localhost:5000"
    echo -e "${WHITE}🗑  Uninstall:${NC}         orion-gui-uninstall"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}Quick Start:${NC}"
    echo ""
    echo -e "  ${GREEN}orion-gui${NC}              Launch GUI"
    echo -e "  ${GREEN}ollama pull OmniNode/Orion:V1.1${NC}   Pull model"
    echo -e "  ${GREEN}orion-gui-uninstall${NC}    Remove GUI"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}Systemd Service (optional):${NC}"
    echo ""

    if [ "$EUID" -eq 0 ]; then
        echo -e "  ${GREEN}sudo systemctl enable orion-gui${NC}"
        echo -e "  ${GREEN}sudo systemctl start orion-gui${NC}"
    else
        echo -e "  ${GREEN}systemctl --user enable orion-gui${NC}"
        echo -e "  ${GREEN}systemctl --user start orion-gui${NC}"
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ==========================================
# LAUNCH OPTION
# ==========================================

ask_launch() {
    echo ""
    read -p "Launch Orion GUI now? (y/n): " LAUNCH_NOW

    if [[ "$LAUNCH_NOW" =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Launching Orion GUI..."
        exec "$BIN_DIR/orion-gui"
    else
        echo ""
        log_info "Run 'orion-gui' to start later"
        echo ""
    fi
}

# ==========================================
# MAIN MENU
# ==========================================

show_menu() {
    print_banner

    echo -e "${WHITE}Choose an option:${NC}"
    echo ""
    echo "  1) 🚀 Full Install (recommended)"
    echo "  2) 📦 Install Ollama only"
    echo "  3) 🖥  Install Orion GUI only"
    echo "  4) 📥 Pull Orion model only"
    echo "  5) 🔄 Update Orion GUI"
    echo "  6) 🗑  Uninstall Orion GUI"
    echo "  7) 🔍 Check status"
    echo "  8) ❌ Exit"
    echo ""
    read -p "Choice (1-8): " MENU_CHOICE

    case $MENU_CHOICE in
        1) full_install ;;
        2) check_system && install_ollama ;;
        3) check_system && check_dependencies && install_orion_gui && add_to_path && print_summary ;;
        4) pull_orion_model ;;
        5) update_install ;;
        6) uninstall ;;
        7) check_status ;;
        8) echo "Goodbye! 👋" && exit 0 ;;
        *) log_error "Invalid choice" && show_menu ;;
    esac
}

# ==========================================
# FULL INSTALL
# ==========================================

full_install() {
    check_system
    check_dependencies
    check_ollama
    install_orion_gui
    add_to_path
    pull_orion_model
    print_summary
    ask_launch
}

# ==========================================
# UPDATE
# ==========================================

update_install() {
    log_step "Updating Orion GUI"

    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Orion GUI is not installed"
        log_info "Run full install first"
        exit 1
    fi

    cd "$INSTALL_DIR"

    if [ -d ".git" ]; then
        log_info "Pulling latest changes..."
        git pull origin main
        log_success "Updated from git"
    else
        log_info "Re-downloading files..."
        download_files
        log_success "Files updated"
    fi

    # Update packages
    if [ -n "$VENV_DIR" ] && [ -d "$VENV_DIR" ]; then
        "$VENV_DIR/bin/pip" install --upgrade flask requests pyyaml -q
    else
        $PYTHON_CMD -m pip install --user --upgrade flask requests pyyaml -q
    fi

    log_success "Orion GUI updated!"
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
        echo "  rm -f $DESKTOP_DIR/orion-gui.desktop"
    fi
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

    # Ollama installed
    if command -v ollama &>/dev/null; then
        log_success "Ollama: $(ollama --version 2>&1 || echo 'installed')"
    else
        log_error "Ollama: not installed"
    fi

    # Ollama running
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('models',[])))" 2>/dev/null || echo "?")
        log_success "Ollama server: running ($MODELS models)"
    else
        log_error "Ollama server: not running"
    fi

    # Orion GUI installed
    if [ -d "$INSTALL_DIR" ]; then
        log_success "Orion GUI: installed at $INSTALL_DIR"
    else
        log_error "Orion GUI: not installed"
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
# ENTRY POINT
# ==========================================

# Check for command line arguments
case "${1:-}" in
    --install|-i)
        full_install
        ;;
    --update|-u)
        update_install
        ;;
    --uninstall|-r)
        uninstall
        ;;
    --status|-s)
        check_status
        ;;
    --ollama)
        check_system && install_ollama
        ;;
    --pull)
        pull_orion_model
        ;;
    --help|-h)
        echo ""
        echo "Orion GUI Installer"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --install, -i      Full installation"
        echo "  --update, -u       Update existing install"
        echo "  --uninstall, -r    Remove Orion GUI"
        echo "  --status, -s       Check system status"
        echo "  --ollama           Install Ollama only"
        echo "  --pull             Pull Orion model"
        echo "  --help, -h         Show this help"
        echo ""
        echo "No arguments = interactive menu"
        echo ""
        ;;
    *)
        show_menu
        ;;
esac