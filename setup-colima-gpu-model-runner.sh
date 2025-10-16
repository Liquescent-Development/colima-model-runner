#!/bin/bash
# setup-colima-gpu-model-runner.sh
#
# This script sets up Docker Model Runner with GPU support on macOS Apple Silicon
# using Colima instead of Docker Desktop.
#
# Prerequisites:
# - macOS with Apple Silicon (M1/M2/M3/M4)
# - Homebrew installed
# - Colima installed (brew install colima)
#
# What this script does:
# 1. Installs dependencies (llama.cpp, Go, Docker CLI)
# 2. Builds model-runner from forked repo with GPU fixes
# 3. Sets up model-runner as a macOS service (launchd)
# 4. Configures macOS Docker CLI to use the host service
# 5. Tests the setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
FORK_REPO="https://github.com/Liquescent-Development/model-runner"
INSTALL_DIR="$HOME/.local/share/model-runner"
BIN_DIR="$HOME/.local/bin"
LAUNCH_AGENT_LABEL="com.liquescent.model-runner"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"
MODEL_RUNNER_PORT=12434

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script only works on macOS"
        exit 1
    fi

    # Check Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        log_error "This script requires Apple Silicon (M1/M2/M3/M4)"
        exit 1
    fi

    # Check Homebrew
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is not installed. Install from https://brew.sh"
        exit 1
    fi

    # Check Colima
    if ! command -v colima &> /dev/null; then
        log_warn "Colima not found. Installing..."
        brew install colima
    fi

    log_info "Prerequisites check passed!"
}

install_dependencies() {
    log_info "Installing dependencies..."

    # Install llama.cpp with Metal support
    if ! command -v llama-server &> /dev/null; then
        log_info "Installing llama.cpp..."
        brew install llama.cpp
    else
        log_info "llama.cpp already installed"
    fi

    # Install Go
    if ! command -v go &> /dev/null; then
        log_info "Installing Go..."
        brew install go
    else
        log_info "Go already installed ($(go version))"
    fi

    # Install Docker CLI (includes docker-model plugin)
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker CLI..."
        brew install docker
    else
        log_info "Docker CLI already installed ($(docker --version))"
    fi

    # Verify docker model plugin is available
    if docker model version &> /dev/null 2>&1 || docker model --help &> /dev/null 2>&1; then
        log_info "✓ docker model plugin is available"
    else
        log_warn "docker model plugin not found. You may need to update Docker CLI:"
        log_warn "  brew upgrade docker"
    fi

    # Ensure Xcode Command Line Tools are installed (for CGO)
    if ! xcode-select -p &> /dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_warn "Please complete the Xcode CLT installation and run this script again"
        exit 0
    fi
}

build_model_runner() {
    log_info "Building model-runner from forked repository..."

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Clone or update repository
    if [ -d "$INSTALL_DIR/repo" ]; then
        log_info "Updating existing repository..."
        cd "$INSTALL_DIR/repo"
        git pull
    else
        log_info "Cloning repository..."
        git clone "$FORK_REPO" "$INSTALL_DIR/repo"
        cd "$INSTALL_DIR/repo"
    fi

    # Build with CGO enabled (for Metal support)
    log_info "Building model-runner binary..."
    CGO_ENABLED=1 make build

    # Install binary
    mkdir -p "$BIN_DIR"
    cp model-runner "$BIN_DIR/model-runner"
    chmod +x "$BIN_DIR/model-runner"

    log_info "model-runner installed to $BIN_DIR/model-runner"
}

setup_launch_daemon() {
    log_info "Setting up model-runner as a macOS service..."

    # Stop existing service if running
    if launchctl list | grep -q "$LAUNCH_AGENT_LABEL"; then
        log_info "Stopping existing service..."
        launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    fi

    # Create LaunchAgent plist
    cat > "$LAUNCH_AGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_DIR/model-runner</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>MODEL_RUNNER_PORT</key>
        <string>$MODEL_RUNNER_PORT</string>
        <key>LLAMA_SERVER_PATH</key>
        <string>/opt/homebrew/bin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/model-runner.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/model-runner.err</string>
</dict>
</plist>
EOF

    # Load the service
    log_info "Starting model-runner service..."
    launchctl load "$LAUNCH_AGENT_PLIST"

    # Wait for it to start
    sleep 3

    # Check if it's running
    if launchctl list | grep -q "$LAUNCH_AGENT_LABEL"; then
        log_info "model-runner service is running!"
    else
        log_error "Failed to start model-runner service"
        log_info "Check logs at: $HOME/Library/Logs/model-runner.log"
        exit 1
    fi
}

verify_gpu_support() {
    log_info "Verifying GPU support..."

    # Wait for service to be ready
    sleep 2

    # Check the logs for GPU detection
    if grep -q "gpuSupport=true" "$HOME/Library/Logs/model-runner.log"; then
        log_info "✓ GPU support detected!"
        return 0
    else
        log_warn "GPU support not detected. Check logs:"
        log_warn "  tail -f $HOME/Library/Logs/model-runner.log"
        return 1
    fi
}

test_service() {
    log_info "Testing model-runner service..."

    # Test basic connectivity
    if curl -sf http://localhost:$MODEL_RUNNER_PORT/models > /dev/null; then
        log_info "✓ Service is responding on port $MODEL_RUNNER_PORT"
    else
        log_error "Service is not responding"
        log_info "Check logs at: $HOME/Library/Logs/model-runner.log"
        exit 1
    fi
}

setup_colima() {
    log_info "Setting up Colima..."

    # Check if Colima is running
    if ! colima status &> /dev/null; then
        log_info "Starting Colima..."
        colima start --cpu 4 --memory 8 --disk 60 --vm-type=vz
    else
        log_info "Colima is already running"
    fi
}

configure_docker_cli() {
    log_info "Configuring Docker CLI to use host model-runner..."

    # The Docker model plugin on macOS should automatically detect localhost:12434
    # But we can add configuration to be explicit

    # Add to shell profile for MODEL_RUNNER_HOST env var (optional but explicit)
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "MODEL_RUNNER_HOST" "$SHELL_RC" 2>/dev/null; then
            log_info "Adding MODEL_RUNNER_HOST to $SHELL_RC"
            cat >> "$SHELL_RC" << 'EOF'

# Docker Model Runner (GPU-accelerated)
export MODEL_RUNNER_HOST="http://localhost:12434"
EOF
            log_info "Added MODEL_RUNNER_HOST to shell profile"
            log_warn "Run 'source $SHELL_RC' or restart your terminal to apply"
        else
            log_info "MODEL_RUNNER_HOST already configured in shell profile"
        fi
    fi

    # Set for current session
    export MODEL_RUNNER_HOST="http://localhost:12434"
}

test_docker_model_cli() {
    log_info "Testing docker model CLI..."

    # Test basic functionality
    export MODEL_RUNNER_HOST="http://localhost:12434"

    if docker model ls &> /dev/null; then
        log_info "✓ docker model CLI is working!"
    else
        log_warn "docker model CLI test returned an error, but this might be normal if no models are installed yet"
    fi
}

print_usage_info() {
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════╗
║                    🎉 Installation Complete! 🎉                        ║
╚════════════════════════════════════════════════════════════════════════╝

Docker Model Runner with GPU support is now running on your system!

⚠️  IMPORTANT: Run this command now or restart your terminal:
    source ~/.zshrc  # or ~/.bashrc if you use bash

📋 Quick Start Guide:

1. Pull a model:
   docker model pull ai/llama3.2:3b-instruct-q4_K_M

2. List models:
   docker model ls

3. Run inference (single prompt):
   docker model run ai/llama3.2:3b-instruct-q4_K_M "Hello, how are you?"

4. Run inference (interactive):
   docker model run ai/llama3.2:3b-instruct-q4_K_M

5. Use in containers:
   docker run -e OPENAI_API_BASE=http://host.lima.internal:12434/v1 your-app

6. Use OpenAI-compatible API:
   curl http://localhost:12434/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "ai/llama3.2:3b-instruct-q4_K_M",
       "messages": [{"role": "user", "content": "Hello!"}]
     }'

🔍 Monitoring & Troubleshooting:

View logs:
  tail -f ~/Library/Logs/model-runner.log

Check service status:
  launchctl list | grep model-runner

Monitor GPU usage:
  sudo powermetrics --samplers gpu_power -i 1000

Restart service:
  launchctl unload ~/Library/LaunchAgents/com.liquescent.model-runner.plist
  launchctl load ~/Library/LaunchAgents/com.liquescent.model-runner.plist

Stop service:
  launchctl unload ~/Library/LaunchAgents/com.liquescent.model-runner.plist

API endpoint:
  http://localhost:12434

🎯 What's Running:

✓ model-runner service on macOS host (with Metal GPU)
✓ llama.cpp with Metal acceleration
✓ Colima (Docker daemon)
✓ docker model CLI on macOS

📚 Documentation:
  - Model Runner: https://docs.docker.com/ai/model-runner/
  - Your fork: https://github.com/Liquescent-Development/model-runner

Happy inferencing! 🚀
EOF
}

# Main installation flow
main() {
    log_info "Starting Docker Model Runner GPU Setup for Colima"
    echo ""

    check_prerequisites
    install_dependencies
    build_model_runner
    setup_launch_daemon
    verify_gpu_support
    test_service
    setup_colima
    configure_docker_cli
    test_docker_model_cli

    echo ""
    print_usage_info
}

# Run main function
main "$@"