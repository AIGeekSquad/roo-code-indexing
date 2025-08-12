# Roo Code Indexing Docker Setup

A production-ready Docker setup for local code indexing using Qdrant vector database and Ollama for embeddings. This configuration provides a self-contained environment for the Roo code indexing system. See [roo](https://docs.roocode.com/features/codebase-indexing?utm_source=extension&utm_medium=ide&utm_campaign=settings)

## 🚀 Quick Start

1. **Clone or download this repository**
2. **Configure your environment** (optional):

   ```bash
   cp .env.example .env
   # Edit .env to customize settings
   ```

3. **Run the setup script**:

   ```bash
   # On Linux/macOS:
   chmod +x setup.sh
   ./setup.sh
   
   # On Windows (PowerShell):
   .\setup.ps1
   
   # On Windows (using Git Bash or WSL):
   bash setup.sh
   
   # Or manually:
   docker-compose up -d
   ```

## 📋 System Requirements

### Memory Requirements

- **Minimum**: 16GB RAM (for `nomic-embed-text` model)
- **Recommended**: 24GB RAM (for `mxbai-embed-large` model)
- **Storage**: 10GB+ free space for models and data

### Software Requirements

- Docker 20.10+
- Docker Compose 2.0+
- curl (for health checks)

## 🎯 Embedding Model Selection

Choose between two embedding models based on your system capabilities:

### nomic-embed-text (Default)

- **Dimensions**: 768
- **Memory**: 16GB minimum
- **Performance**: Good balance of speed and quality
- **Best for**: Most users, smaller systems

### mxbai-embed-large

- **Dimensions**: 1024
- **Memory**: 24GB minimum
- **Performance**: Higher quality embeddings
- **Best for**: High-end systems, maximum quality

To change the model, edit the `EMBEDDING_MODEL` variable in your `.env` file:

```bash
# For nomic-embed-text (default)
EMBEDDING_MODEL=nomic-embed-text

# For mxbai-embed-large
EMBEDDING_MODEL=mxbai-embed-large
```

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Core configuration
EMBEDDING_MODEL=nomic-embed-text
QDRANT_PORT=6333
OLLAMA_PORT=11434

# Memory limits (adjust based on your system)
OLLAMA_MEMORY_LIMIT=24G
OLLAMA_MEMORY_RESERVATION=16G
QDRANT_MEMORY_LIMIT=4G

# Storage paths
QDRANT_STORAGE_PATH=./data/qdrant
OLLAMA_MODELS_PATH=./data/ollama
```

### Port Mapping

| Service | Port | Purpose |
|---------|------|---------|
| Qdrant HTTP | 6333 | Vector database API |
| Qdrant gRPC | 6334 | High-performance gRPC API |
| Ollama | 11434 | Embedding model API |

## 📁 Data Persistence

### Local Storage Configuration

Data is persisted in local directories:

```
./data/
├── qdrant/     # Vector database storage
└── ollama/     # Downloaded models storage
```

These directories are automatically created and mounted as Docker volumes for data persistence across container restarts.

### Volume Management

- **Qdrant data**: Stored in `./data/qdrant`
- **Ollama models**: Stored in `./data/ollama`
- **Backup**: Simply copy the `./data` directory
- **Reset**: Delete `./data` directory and restart services

## 🔄 Service Management

### Starting Services

```bash
# Start all services
docker-compose up -d

# Start with logs
docker-compose up

# Using the setup script
./setup.sh
```

### Stopping Services

```bash
# Stop services (keeps data)
docker-compose down

# Stop and remove volumes (deletes data)
docker-compose down -v
```

### Restarting Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart qdrant
docker-compose restart ollama
```

### Auto-start with System Boot

The services are configured with `restart: unless-stopped` in the [`docker-compose.yml`](docker-compose.yml:16), which means they will automatically restart if they crash or if Docker restarts. To enable full auto-start on system boot across any operating system:

#### Simple Cross-Platform Setup

1. **Configure Docker to start at login/boot**:
   - **Windows**: Docker Desktop → Settings → General → "Start Docker Desktop when you log in"
   - **macOS**: Docker Desktop → Settings → General → "Start Docker Desktop when you log in"
   - **Linux**: Enable Docker service: `sudo systemctl enable docker`

2. **Start the services once**:

   ```bash
   docker-compose up -d
   ```

3. **That's it!** The services will now:
   - Start automatically when Docker starts (at system boot/login)
   - Restart automatically if they crash or stop unexpectedly
   - Continue running until you explicitly stop them with `docker-compose down`

#### How It Works

The [`docker-compose.yml`](docker-compose.yml:16) includes `restart: unless-stopped` for both services, which means:

- Services restart automatically if they exit unexpectedly
- Services start automatically when Docker daemon starts
- Services only stop when explicitly stopped with `docker-compose down`
- Services survive system reboots as long as Docker starts automatically

#### Advanced Platform-Specific Options

If you need more control, you can also use platform-specific service management:

<details>
<summary>Linux (systemd) - Click to expand</summary>

Create a systemd service for more granular control:

```bash
# Create service file
sudo tee /etc/systemd/system/roo-indexing.service > /dev/null <<EOF
[Unit]
Description=Roo Code Indexing Services
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl enable roo-indexing.service
sudo systemctl start roo-indexing.service
```

</details>

<details>
<summary>Windows (Task Scheduler) - Click to expand</summary>

For more control than Docker Desktop's auto-start:

1. Open Task Scheduler
2. Create Basic Task → "Start Roo Indexing"
3. Trigger: "When the computer starts"
4. Action: "Start a program"
5. Program: `docker-compose`
6. Arguments: `up -d`
7. Start in: `C:\path\to\your\roo-docker-setup`

</details>

<details>
<summary>macOS (launchd) - Click to expand</summary>

Create a launch daemon for system-level startup:

```bash
# Create plist file
sudo tee /Library/LaunchDaemons/com.roo.indexing.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.roo.indexing</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/docker-compose</string>
        <string>up</string>
        <string>-d</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$(pwd)</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

# Load the service
sudo launchctl load /Library/LaunchDaemons/com.roo.indexing.plist
```

</details>

## ✅ Verification

### Health Checks

The setup includes automatic health checks. Verify services are running:

```bash
# Check service status
docker-compose ps

# Check health status
docker-compose logs qdrant
docker-compose logs ollama

# Manual health checks
curl http://localhost:6333/readyz
curl http://localhost:11434/api/tags
```

### Testing the Setup

1. **Verify Qdrant is accessible**:

   ```bash
   curl -X GET http://localhost:6333/collections
   ```

2. **Verify Ollama has the embedding model**:

   ```bash
   curl http://localhost:11434/api/tags
   ```

3. **Test embedding generation**:

   ```bash
   curl -X POST http://localhost:11434/api/embeddings \
     -H "Content-Type: application/json" \
     -d '{
       "model": "nomic-embed-text",
       "prompt": "Hello world"
     }'
   ```

### Using the Setup Scripts

#### Linux/macOS (Bash)

The bash setup script provides additional verification options:

```bash
# Verify current setup
./setup.sh --verify

# Pull embedding model only
./setup.sh --pull-model

# Full setup with verification
./setup.sh
```

#### Windows (PowerShell)

The PowerShell setup script provides the same functionality:

```powershell
# Verify current setup
.\setup.ps1 -Verify

# Pull embedding model only
.\setup.ps1 -PullModel

# Full setup with verification
.\setup.ps1

# Show help
.\setup.ps1 -Help
```

## 🔍 Troubleshooting

### Common Issues

#### Services Won't Start

1. **Check Docker is running**:

   ```bash
   docker --version
   docker-compose --version
   ```

2. **Check port conflicts**:

   ```bash
   # Check if ports are in use
   netstat -an | grep 6333
   netstat -an | grep 11434
   ```

3. **Check available memory**:

   ```bash
   free -h  # Linux
   # Ensure you have enough RAM for your chosen model
   ```

#### Ollama Model Issues

1. **Model not found**:

   ```bash
   # Pull model manually
   docker exec roo-ollama ollama pull nomic-embed-text
   ```

2. **Out of memory errors**:
   - Reduce `OLLAMA_MEMORY_LIMIT` in `.env`
   - Switch to `nomic-embed-text` model
   - Close other applications

#### Qdrant Connection Issues

1. **Check Qdrant logs**:

   ```bash
   docker-compose logs qdrant
   ```

2. **Reset Qdrant data**:

   ```bash
   docker-compose down
   rm -rf ./data/qdrant
   docker-compose up -d
   ```

#### Permission Issues

1. **Linux/macOS**:

   ```bash
   # Fix data directory permissions
   sudo chown -R $USER:$USER ./data
   chmod -R 755 ./data
   ```

2. **Windows**:
   - Ensure Docker has access to the drive
   - Run Docker Desktop as administrator if needed

### Performance Optimization

1. **Increase memory limits** in `.env`:

   ```bash
   OLLAMA_MEMORY_LIMIT=32G
   QDRANT_MEMORY_LIMIT=8G
   ```

2. **Use SSD storage** for better I/O performance

3. **Enable GPU support** (NVIDIA only):

   ```bash
   # Uncomment GPU lines in docker-compose.yml
   # Ensure nvidia-docker is installed
   ```

### Logs and Monitoring

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f qdrant
docker-compose logs -f ollama

# View resource usage
docker stats
```

## 🔧 Advanced Configuration

### GPU Support (NVIDIA)

1. Install [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

2. Uncomment GPU configuration in `docker-compose.yml`:

   ```yaml
   runtime: nvidia
   environment:
     - NVIDIA_VISIBLE_DEVICES=all
   ```

3. Set `ENABLE_GPU=true` in `.env`

### Custom Network Configuration

The services use a custom Docker network `roo-code-indexing` for isolation. To connect external services:

```bash
# Connect another container to the network
docker network connect roo-code-indexing your-container-name
```

### Scaling Considerations

For production deployments:

1. **Use external volumes** for better performance
2. **Configure resource limits** based on workload
3. **Set up monitoring** with Prometheus/Grafana
4. **Configure backup strategies** for data persistence

## 📚 API Documentation

### Qdrant API

- **Web UI**: <http://localhost:6333/dashboard>
- **API Docs**: <http://localhost:6333/docs>
- **Collections**: <http://localhost:6333/collections>

### Ollama API

- **Models**: <http://localhost:11434/api/tags>
- **Generate**: <http://localhost:11434/api/generate>
- **Embeddings**: <http://localhost:11434/api/embeddings>

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with both embedding models
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review Docker and Docker Compose logs
3. Ensure system requirements are met
4. Verify network connectivity and ports

For additional support, please create an issue with:

- System specifications
- Error messages
- Docker and Docker Compose versions
- Steps to reproduce the issue
