# Colima Model Runner with GPU Support

**Run Docker's AI Model Runner with native GPU acceleration on macOS Apple Silicon — without Docker Desktop.**

This project provides an automated setup script that configures [Docker Model Runner](https://docs.docker.com/ai/model-runner/) to use your Mac's GPU (Metal) for AI inference, using Colima instead of Docker Desktop. Perfect for running local LLMs with optimal performance.

## Why This Project?

### The Problem
Docker has open-sourced their Model Runner and CLI plugin, but they're designed to work exclusively with Docker Desktop. When you try to use `docker model` with open-source alternatives like Colima on macOS, you lose GPU acceleration and fall back to CPU-only inference—resulting in significantly slower performance.

Docker Desktop achieves GPU acceleration by running llama.cpp in an Apple native sandbox with Metal support. However, there was no equivalent solution for users who want a fully open-source Docker setup with Colima.

### The Solution
This project provides a **forked model-runner** with patches that enable the same GPU-accelerated architecture outside of Docker Desktop:

- **Runs llama.cpp in Apple's native sandbox**: Same security model as Docker Desktop, with Metal GPU acceleration
- **Works seamlessly with Colima**: Fully open-source Docker environment
- **Drop-in replacement**: Uses the same `docker model` CLI commands
- **Host-level service**: model-runner runs as a macOS LaunchAgent for direct GPU access

### Benefits
- **Native GPU Performance**: Full Metal acceleration via llama.cpp, just like Docker Desktop
- **Fully Open Source**: Both Colima and our forked model-runner are open source
- **Sandboxed Security**: Models run in Apple's sandbox for container-like security isolation
- **OpenAI-Compatible API**: Drop-in replacement for OpenAI endpoints at `localhost:12434`
- **Container Integration**: Accessible from Colima containers via `host.lima.internal:12434`
- **Automatic Service Management**: Runs as macOS LaunchAgent (starts on boot)

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- [Homebrew](https://brew.sh) installed
- Colima installed: `brew install colima`

## Quick Start

### 1. Run the Setup Script

```bash
git clone https://github.com/Liquescent-Development/colima-model-runner.git
cd colima-model-runner
./setup-colima-gpu-model-runner.sh
```

The script will:
- Install dependencies (llama.cpp, Go, Docker CLI)
- Build model-runner from our [GPU-optimized fork](https://github.com/Liquescent-Development/model-runner)
- Configure model-runner as a macOS LaunchAgent service
- Set up Colima for Docker support
- Test GPU support and connectivity

### 2. Reload Your Shell

```bash
source ~/.zshrc  # or ~/.bashrc if you use bash
```

### 3. Pull and Run a Model

```bash
# Pull a model
docker model pull ai/llama3.2:3b-instruct-q4_K_M

# List installed models
docker model ls

# Run inference (interactive)
docker model run ai/llama3.2:3b-instruct-q4_K_M

# Run inference (single prompt)
docker model run ai/llama3.2:3b-instruct-q4_K_M "Explain quantum computing in simple terms"
```

## Usage Examples

### Command Line Interface

```bash
# Interactive chat
docker model run ai/llama3.2:3b-instruct-q4_K_M

# Single prompt
docker model run ai/llama3.2:3b-instruct-q4_K_M "Write a haiku about code"

# List models
docker model ls

# Remove a model
docker model rm ai/llama3.2:3b-instruct-q4_K_M
```

### OpenAI-Compatible API

```bash
curl http://localhost:12434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ai/llama3.2:3b-instruct-q4_K_M",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### From Docker Containers

```bash
# Use from any container running in Colima
docker run -e OPENAI_API_BASE=http://host.lima.internal:12434/v1 your-app
```

### Python Example

```python
import openai

client = openai.OpenAI(
    base_url="http://localhost:12434/v1",
    api_key="not-needed"
)

response = client.chat.completions.create(
    model="ai/llama3.2:3b-instruct-q4_K_M",
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         macOS Host                          │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ model-runner (LaunchAgent)                         │    │
│  │ • Port: 12434                                      │    │
│  │ • GPU: Metal acceleration via llama.cpp            │    │
│  │ • API: OpenAI-compatible                           │    │
│  └────────────────────────────────────────────────────┘    │
│                           ▲                                 │
│                           │ http://localhost:12434          │
│                           │                                 │
│  ┌────────────────────────┴───────────────────────────┐    │
│  │ docker model CLI                                   │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Colima (Lima VM)                                   │    │
│  │ • Docker daemon                                    │    │
│  │ • Containers access via host.lima.internal:12434   │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Service Management

### Check Service Status

```bash
launchctl list | grep model-runner
```

### View Logs

```bash
# Standard output
tail -f ~/Library/Logs/model-runner.log

# Errors
tail -f ~/Library/Logs/model-runner.err
```

### Restart Service

```bash
launchctl unload ~/Library/LaunchAgents/com.liquescent.model-runner.plist
launchctl load ~/Library/LaunchAgents/com.liquescent.model-runner.plist
```

### Stop Service

```bash
launchctl unload ~/Library/LaunchAgents/com.liquescent.model-runner.plist
```

### Monitor GPU Usage

```bash
sudo powermetrics --samplers gpu_power -i 1000
```

## Verifying GPU Acceleration

Check that GPU support is enabled:

```bash
grep "gpuSupport=true" ~/Library/Logs/model-runner.log
```

You should see output confirming GPU support is active.

## Troubleshooting

### Service Won't Start

1. Check logs: `tail -f ~/Library/Logs/model-runner.err`
2. Verify binary exists: `ls -la ~/.local/bin/model-runner`
3. Ensure Xcode CLT installed: `xcode-select -p`

### GPU Not Detected

1. Verify you're on Apple Silicon: `uname -m` (should show `arm64`)
2. Check llama.cpp installation: `which llama-server`
3. Review model-runner logs for Metal initialization

### Docker Model CLI Issues

```bash
# Ensure environment variable is set
echo $MODEL_RUNNER_HOST  # Should show http://localhost:12434

# Test connectivity
curl http://localhost:12434/models

# Reinstall Docker CLI
brew upgrade docker
```

### Colima Issues

```bash
# Restart Colima
colima stop
colima start --cpu 4 --memory 8 --disk 60 --vm-type=vz

# Check status
colima status
```

## Configuration

### Default Settings

- **Service Port**: 12434
- **Binary Location**: `~/.local/bin/model-runner`
- **Installation Directory**: `~/.local/share/model-runner`
- **Logs**: `~/Library/Logs/model-runner.{log,err}`
- **LaunchAgent**: `~/Library/LaunchAgents/com.liquescent.model-runner.plist`

### Environment Variables

```bash
MODEL_RUNNER_HOST=http://localhost:12434
MODEL_RUNNER_PORT=12434
LLAMA_SERVER_PATH=/opt/homebrew/bin
```

## Performance Tips

1. **Choose the Right Model Size**: Start with quantized models (Q4_K_M) for best speed/quality balance
2. **Monitor GPU Usage**: Use `powermetrics` to verify GPU utilization during inference
3. **Colima Resources**: Allocate enough RAM and CPU for your containers
4. **Model Caching**: Pulled models are cached locally for fast reuse

## Uninstallation

```bash
# Stop and remove service
launchctl unload ~/Library/LaunchAgents/com.liquescent.model-runner.plist
rm ~/Library/LaunchAgents/com.liquescent.model-runner.plist

# Remove binaries and data
rm -rf ~/.local/share/model-runner
rm ~/.local/bin/model-runner

# Remove environment variable from shell profile
# Edit ~/.zshrc or ~/.bashrc and remove MODEL_RUNNER_HOST export
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Related Projects

- [Docker Model Runner](https://docs.docker.com/ai/model-runner/) - Official Docker AI documentation
- [Liquescent-Development/model-runner](https://github.com/Liquescent-Development/model-runner) - Our GPU-optimized fork
- [Colima](https://github.com/abiosoft/colima) - Container runtime for macOS
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - LLM inference with Metal support

## License

See [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/Liquescent-Development/colima-model-runner/issues)
- **Documentation**: See [CLAUDE.md](CLAUDE.md) for development details
- **Docker Model Runner Docs**: https://docs.docker.com/ai/model-runner/
