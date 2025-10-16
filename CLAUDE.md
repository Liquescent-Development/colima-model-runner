# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a setup script for configuring Docker Model Runner with native GPU acceleration on macOS Apple Silicon (M1/M2/M3/M4) using Colima instead of Docker Desktop. The setup leverages llama.cpp with Metal support for optimal GPU performance.

## Core Architecture

The setup creates a complete GPU-accelerated AI inference stack:

1. **Host-Level Service**: `model-runner` runs as a macOS LaunchAgent (not in Docker), providing direct access to Metal GPU acceleration
2. **Fork Repository**: Builds from `https://github.com/Liquescent-Development/model-runner` which includes GPU fixes
3. **Service Configuration**:
   - Port: 12434
   - LaunchAgent: `com.liquescent.model-runner`
   - Logs: `~/Library/Logs/model-runner.log` and `~/Library/Logs/model-runner.err`
   - Binary location: `~/.local/bin/model-runner`
   - Installation directory: `~/.local/share/model-runner`
4. **Docker Integration**: Colima provides Docker daemon while model-runner runs on the host for GPU access
5. **API**: OpenAI-compatible endpoint at `http://localhost:12434`

## Installation Process

The script downloads a pre-built model-runner binary with Metal support:
```bash
curl -L -f -o ~/.local/bin/model-runner \
  https://github.com/Liquescent-Development/model-runner/releases/download/latest-86796e4fe88d883091e2d5c4b6ed5cc522565a90/model-runner-darwin-arm64
chmod +x ~/.local/bin/model-runner
```

This eliminates the need for Go, git, and build tools. The binary is built with CGO enabled for Metal GPU acceleration.

## Service Management

**Start/Stop Service:**
```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.liquescent.model-runner.plist

# Start
launchctl load ~/Library/LaunchAgents/com.liquescent.model-runner.plist

# Check status
launchctl list | grep model-runner
```

**View Logs:**
```bash
tail -f ~/Library/Logs/model-runner.log
tail -f ~/Library/Logs/model-runner.err
```

**Monitor GPU:**
```bash
sudo powermetrics --samplers gpu_power -i 1000
```

## Testing & Validation

**Service Health:**
```bash
curl -sf http://localhost:12434/models
```

**Docker Model CLI:**
```bash
export MODEL_RUNNER_HOST="http://localhost:12434"
docker model ls
docker model pull ai/llama3.2:3b-instruct-q4_K_M
docker model run ai/llama3.2:3b-instruct-q4_K_M "Hello, how are you?"
```

**GPU Verification:**
Check logs for `gpuSupport=true`:
```bash
grep "gpuSupport=true" ~/Library/Logs/model-runner.log
```

## Running the Setup Script

**Prerequisites:**
- macOS Apple Silicon (M1/M2/M3/M4)
- Homebrew installed
- Colima installed (`brew install colima`)

Note: Go, git, and Xcode Command Line Tools are no longer required thanks to the pre-built binary.

**Execute:**
```bash
./setup-colima-gpu-model-runner.sh
```

**Post-Install:**
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Environment Variables

- `MODEL_RUNNER_HOST`: Set to `http://localhost:12434` (added to shell profile by script)
- `MODEL_RUNNER_PORT`: Service port (default: 12434)
- `LLAMA_SERVER_PATH`: Path to llama.cpp binaries (default: `/opt/homebrew/bin`)

## Common Issues

**Script requires:**
- Apple Silicon architecture check (`uname -m` == `arm64`)
- macOS OS check (`$OSTYPE` == `darwin*`)
- Script runs with `set -e` (fail-fast behavior)

**If service fails to start:**
1. Check LaunchAgent logs
2. Verify binary exists at `~/.local/bin/model-runner`
3. Ensure binary has execute permissions: `chmod +x ~/.local/bin/model-runner`
4. Test binary directly: `~/.local/bin/model-runner --help`

## Integration with Containers

Inside Colima containers, reference the host service:
```bash
docker run -e OPENAI_API_BASE=http://host.lima.internal:12434/v1 your-app
```

Note: Colima uses Lima VM, so `host.lima.internal` resolves to the macOS host where model-runner is running.
