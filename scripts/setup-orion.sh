#!/bin/bash
# =============================================
# Orion AI - Full Setup Workflow
# Installs Ollama, Downloads Model, Creates Orion
# Uses existing Modelfile from project root
# =============================================
# Usage: chmod +x scripts/setup-orion.sh && ./scripts/setup-orion.sh
# =============================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Config ---
MODEL_NAME="orion"
GGUF_FILE="Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"
HF_URL="https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"

# Get project root (parent of scripts folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELFILE_PATH="$PROJECT_ROOT/Modelfile"
MODEL_DIR="$PROJECT_ROOT/models"

# =============================================
# HELPER FUNCTIONS
# =============================================

print_banner() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║         ORION AI - FULL SETUP         ║"
    echo "  ║   Local · Private · No Data Exposed   ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}  ✅ $1${NC}"
}

print_error() {
    echo -e "${RED}  ❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}  ℹ  $1${NC}"
}

check_command() {
    command -v "$1" &> /dev/null
}

# =============================================
# STEP 0: DETECT OS
# =============================================

detect_os() {
    print_step "Detecting Operating System"

    OS_TYPE=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"
        print_success "Detected: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="mac"
        print_success "Detected: macOS"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        OS_TYPE="windows"
        print_success "Detected: Windows (Git Bash / WSL)"
    else
        print_error "Unknown OS: $OSTYPE"
        exit 1
    fi
}

# =============================================
# STEP 1: CHECK PROJECT STRUCTURE
# =============================================

check_project() {
    print_step "Checking Project Structure"

    print_info "Project root: $PROJECT_ROOT"
    print_info "Scripts dir: $SCRIPT_DIR"
    print_info "Modelfile path: $MODELFILE_PATH"

    # Check if Modelfile exists in root
    if [ -f "$MODELFILE_PATH" ]; then
        print_success "Found Modelfile at root"
    else
        print_error "Modelfile not found at $MODELFILE_PATH"
        print_error "Please create your Modelfile in the project root."
        exit 1
    fi

    # Create models directory if needed
    mkdir -p "$MODEL_DIR"
    print_success "Models directory: $MODEL_DIR"
}

# =============================================
# STEP 2: CHECK DEPENDENCIES
# =============================================

check_dependencies() {
    print_step "Checking Dependencies"

    if check_command curl; then
        print_success "curl is installed"
    else
        print_error "curl is not installed. Installing..."
        if [[ "$OS_TYPE" == "linux" ]]; then
            sudo apt-get install -y curl || sudo yum install -y curl
        elif [[ "$OS_TYPE" == "mac" ]]; then
            brew install curl
        fi
    fi

    # Check disk space
    AVAILABLE_SPACE=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G' || echo "10")
    if [ "$AVAILABLE_SPACE" -lt 6 ]; then
        print_error "Not enough disk space. Need at least 6GB. Available: ${AVAILABLE_SPACE}GB"
        exit 1
    else
        print_success "Disk space OK: ${AVAILABLE_SPACE}GB available"
    fi
}

# =============================================
# STEP 3: INSTALL OLLAMA
# =============================================

install_ollama() {
    print_step "Installing Ollama"

    if check_command ollama; then
        OLLAMA_VERSION=$(ollama --version 2>/dev/null || echo "installed")
        print_success "Ollama already installed: $OLLAMA_VERSION"
        return
    fi

    print_info "Ollama not found. Installing..."

    if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "mac" ]]; then
        curl -fsSL https://ollama.com/install.sh | sh

        if [ $? -eq 0 ]; then
            print_success "Ollama installed successfully!"
        else
            print_error "Ollama installation failed."
            exit 1
        fi

    elif [[ "$OS_TYPE" == "windows" ]]; then
        print_info "Windows detected. Downloading installer..."
        curl -L -o "$PROJECT_ROOT/OllamaSetup.exe" "https://ollama.com/download/OllamaSetup.exe"
        print_info "Run OllamaSetup.exe then re-run this script."
        exit 0
    fi
}

# =============================================
# STEP 4: START OLLAMA SERVICE
# =============================================

start_ollama_service() {
    print_step "Starting Ollama Service"

    if curl -s http://localhost:11434 &> /dev/null; then
        print_success "Ollama service is already running"
        return
    fi

    print_info "Starting Ollama..."

    if [[ "$OS_TYPE" == "linux" ]]; then
        if check_command systemctl; then
            sudo systemctl enable ollama 2>/dev/null || true
            sudo systemctl start ollama 2>/dev/null || true
        fi
        if ! curl -s http://localhost:11434 &> /dev/null; then
            nohup ollama serve > /tmp/ollama.log 2>&1 &
            sleep 3
        fi

    elif [[ "$OS_TYPE" == "mac" ]]; then
        nohup ollama serve > /tmp/ollama.log 2>&1 &
        sleep 3
    fi

    # Wait for service
    for i in {1..10}; do
        if curl -s http://localhost:11434 &> /dev/null; then
            print_success "Ollama running at http://localhost:11434"
            return
        fi
        print_info "Waiting for Ollama... ($i/10)"
        sleep 2
    done

    print_error "Could not start Ollama. Check /tmp/ollama.log"
    exit 1
}

# =============================================
# STEP 5: DOWNLOAD MODEL
# =============================================

download_model() {
    print_step "Downloading Model"

    cd "$MODEL_DIR"

    if [ -f "$GGUF_FILE" ]; then
        FILE_SIZE=$(du -sh "$GGUF_FILE" | cut -f1)
        print_success "Model already exists ($FILE_SIZE). Skipping."
        return
    fi

    print_info "Downloading from Hugging Face..."
    print_info "Size: ~4.1GB"
    print_info "Location: $MODEL_DIR/$GGUF_FILE"
    echo ""

    curl -L \
        --progress-bar \
        -C - \
        --retry 5 \
        --retry-delay 5 \
        -o "$GGUF_FILE" \
        "$HF_URL"

    if [ $? -eq 0 ] && [ -f "$GGUF_FILE" ]; then
        FILE_SIZE=$(du -sh "$GGUF_FILE" | cut -f1)
        print_success "Download complete! Size: $FILE_SIZE"
    else
        print_error "Download failed."

        # Fallback URL
        print_info "Trying fallback URL..."
        FALLBACK_URL="https://us.aws.cdn.hf.co/xet-bridge-us/664e3ef36bc1025819154a01/61b301599ad6e7ee371b60654026a34134dac0ddfc94a2b37ed06ebb589a0644?user_id=public&X-Xet-Cas-Uid=public&response-content-disposition=inline%3B+filename*%3DUTF-8%27%27Mistral-7B-Instruct-v0.3-Q4_K_M.gguf%3B+filename%3D%22Mistral-7B-Instruct-v0.3-Q4_K_M.gguf%22%3B&Expires=1786576219&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly91cy5hd3MuY2RuLmhmLmNvL3hldC1icmlkZ2UtdXMvNjY0ZTNlZjM2YmMxMDI1ODE5MTU0YTAxLzYxYjMwMTU5OWFkNmU3ZWUzNzFiNjA2NTQwMjZhMzQxMzRkYWMwZGRmYzk0YTJiMzdlZDA2ZWJiNTg5YTA2NDRcXD91c2VyX2lkPXB1YmxpYyZYLVhldC1DYXMtVWlkPXB1YmxpYyZyZXNwb25zZS1jb250ZW50LWRpc3Bvc2l0aW9uPWlubGluZSUzQitmaWxlbmFtZSUyQSUzRFVURi04JTI3JTI3TWlzdHJhbC03Qi1JbnN0cnVjdC12MC4zLVE0X0tfTS5nZ3VmJTNCK2ZpbGVuYW1lJTNEJTIyTWlzdHJhbC03Qi1JbnN0cnVjdC12MC4zLVE0X0tfTS5nZ3VmJTIyJTNCIiwiQ29uZGl0aW9uIjp7IkRhdGVMZXNzVGhhbiI6eyJFcG9jaFRpbWUiOjE3ODY1NzYyMTl9fX1dfQ__&Signature=MEUCIQCaKe4san9esOBFME5t2-C%7EKOygNFVTTybFR09kpubcPAIgXuqFPFsD6-Gw3nEa6iDAEnPPRaQFsz6hVw-82SnTLJs_&Key-Pair-Id=01KXEF4KZ1B6FV465MAWR4M21F"

        curl -L --progress-bar -C - -o "$GGUF_FILE" "$FALLBACK_URL"

        if [ $? -ne 0 ]; then
            print_error "Both downloads failed."
            exit 1
        fi
    fi
}

# =============================================
# STEP 6: BUILD MODEL IN OLLAMA
# =============================================

build_model() {
    print_step "Building Orion in Ollama"

    cd "$PROJECT_ROOT"

    print_info "Using Modelfile: $MODELFILE_PATH"
    print_info "Model file: $MODEL_DIR/$GGUF_FILE"

    # Create a temp modelfile with the correct absolute path
    TEMP_MODELFILE=$(mktemp /tmp/Modelfile.XXXXXX)

    # Replace the FROM line with the absolute path to the gguf file
    sed "s|FROM .*|FROM $MODEL_DIR/$GGUF_FILE|g" "$MODELFILE_PATH" > "$TEMP_MODELFILE"

    print_info "Temp Modelfile contents:"
    cat "$TEMP_MODELFILE"
    echo ""

    print_info "Running: ollama create $MODEL_NAME -f $TEMP_MODELFILE"

    ollama create "$MODEL_NAME" -f "$TEMP_MODELFILE"
    BUILD_STATUS=$?

    rm -f "$TEMP_MODELFILE"

    if [ $BUILD_STATUS -eq 0 ]; then
        print_success "Orion model created!"
    else
        print_error "Failed to create model."
        exit 1
    fi
}

# =============================================
# STEP 7: VERIFY MODEL
# =============================================

verify_model() {
    print_step "Verifying Orion"

    if ollama list | grep -q "$MODEL_NAME"; then
        print_success "Orion is ready:"
        echo ""
        ollama list | grep "$MODEL_NAME"
        echo ""
    else
        print_error "Model not found."
        exit 1
    fi
}

# =============================================
# STEP 8: FINAL INSTRUCTIONS
# =============================================

print_final() {
    echo -e "\n${GREEN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║       🎉 ORION IS READY TO USE!          ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${CYAN}  Usage:${NC}"
    echo ""
    echo -e "  ${YELLOW}# Chat:${NC}"
    echo "  ollama run orion"
    echo ""
    echo -e "  ${YELLOW}# Single prompt:${NC}"
    echo "  ollama run orion \"Your question here\""
    echo ""
    echo -e "  ${YELLOW}# API:${NC}"
    echo "  curl http://localhost:11434/api/generate \\"
    echo "    -d '{\"model\":\"orion\",\"prompt\":\"Hello\",\"stream\":false}'"
    echo ""
    echo -e "${CYAN}  Project: $PROJECT_ROOT${NC}"
    echo -e "${GREEN}  ✅ 100% Local — No data exposed${NC}"
    echo ""
}

# =============================================
# MAIN
# =============================================

main() {
    print_banner
    detect_os
    check_project
    check_dependencies
    install_ollama
    start_ollama_service
    download_model
    build_model
    verify_model
    print_final
}

main
