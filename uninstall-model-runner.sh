#!/bin/bash
# uninstall-model-runner.sh
#
# Removes only the model-runner service and binary.
# Leaves llama.cpp, Docker CLI, and Colima installed.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BIN_DIR="$HOME/.local/bin"
CLI_PLUGINS_DIR="$HOME/.docker/cli-plugins"
LAUNCH_AGENT_LABEL="com.liquescent.model-runner"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"

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

log_info "Uninstalling model-runner..."

# Stop and unload LaunchAgent if running
if launchctl list | grep -q "$LAUNCH_AGENT_LABEL"; then
    log_info "Stopping model-runner service..."
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    log_info "✓ Service stopped"
else
    log_info "Service not running"
fi

# Remove LaunchAgent plist
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    log_info "Removing LaunchAgent configuration..."
    rm "$LAUNCH_AGENT_PLIST"
    log_info "✓ LaunchAgent removed"
else
    log_info "LaunchAgent plist not found"
fi

# Remove binary
if [ -f "$BIN_DIR/model-runner" ]; then
    log_info "Removing model-runner binary..."
    rm "$BIN_DIR/model-runner"
    log_info "✓ Binary removed"
else
    log_info "Binary not found"
fi

# Remove docker model CLI plugin
if [ -f "$CLI_PLUGINS_DIR/docker-model" ]; then
    log_info "Removing docker model CLI plugin..."
    rm "$CLI_PLUGINS_DIR/docker-model"
    log_info "✓ CLI plugin removed"
else
    log_info "CLI plugin not found"
fi

# Remove logs
if [ -f "$HOME/Library/Logs/model-runner.log" ]; then
    log_info "Removing logs..."
    rm "$HOME/Library/Logs/model-runner.log" 2>/dev/null || true
    rm "$HOME/Library/Logs/model-runner.err" 2>/dev/null || true
    log_info "✓ Logs removed"
fi

log_info ""
log_info "✓ model-runner uninstalled successfully"
log_info ""
log_info "Note: The following were NOT removed:"
log_info "  - llama.cpp"
log_info "  - Docker CLI"
log_info "  - Colima"
log_info "  - MODEL_RUNNER_HOST environment variable in shell profile"
log_info ""
log_info "To remove the environment variable, edit your ~/.zshrc or ~/.bashrc"
log_info "and remove the MODEL_RUNNER_HOST export line."
