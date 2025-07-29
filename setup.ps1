# Roo Code Indexing Docker Setup Script for Windows
# This PowerShell script automates the initial setup of Qdrant and Ollama services

param(
    [switch]$Help,
    [switch]$Verify,
    [switch]$PullModel
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to check system requirements
function Test-Requirements {
    Write-Status "Checking system requirements..."
    
    # Check if Docker is installed
    if (-not (Test-Command "docker")) {
        Write-Error "Docker is not installed. Please install Docker Desktop for Windows first."
        Write-Host "Download from: https://www.docker.com/products/docker-desktop" -ForegroundColor Cyan
        exit 1
    }
    
    # Check if Docker is running
    try {
        docker version | Out-Null
    }
    catch {
        Write-Error "Docker is not running. Please start Docker Desktop."
        exit 1
    }
    
    # Check if Docker Compose is available
    $composeAvailable = $false
    if (Test-Command "docker-compose") {
        $composeAvailable = $true
        $script:ComposeCommand = "docker-compose"
    }
    elseif ((docker compose version 2>$null) -ne $null) {
        $composeAvailable = $true
        $script:ComposeCommand = "docker compose"
    }
    
    if (-not $composeAvailable) {
        Write-Error "Docker Compose is not available. Please ensure Docker Desktop is properly installed."
        exit 1
    }
    
    # Check available memory (Windows)
    try {
        $totalMemoryGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
        Write-Status "Total system memory: $totalMemoryGB GB"
        
        if ($totalMemoryGB -lt 16) {
            Write-Warning "System has less than 16GB RAM. Consider using nomic-embed-text model."
        }
    }
    catch {
        Write-Warning "Could not determine system memory."
    }
    
    Write-Success "System requirements check passed"
}

# Function to create necessary directories
function New-DataDirectories {
    Write-Status "Creating data directories..."
    
    # Load environment variables if .env exists
    $envVars = @{}
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^([^#][^=]+)=(.*)$") {
                $envVars[$matches[1]] = $matches[2]
            }
        }
    }
    
    # Create directories with defaults
    $qdrantDir = if ($envVars["QDRANT_STORAGE_PATH"]) { $envVars["QDRANT_STORAGE_PATH"] } else { ".\data\qdrant" }
    $ollamaDir = if ($envVars["OLLAMA_MODELS_PATH"]) { $envVars["OLLAMA_MODELS_PATH"] } else { ".\data\ollama" }
    
    New-Item -ItemType Directory -Path $qdrantDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ollamaDir -Force | Out-Null
    
    Write-Success "Data directories created: $qdrantDir, $ollamaDir"
}

# Function to create .env file if it doesn't exist
function Initialize-EnvFile {
    if (-not (Test-Path ".env")) {
        Write-Status "Creating .env file from template..."
        Copy-Item ".env.example" ".env"
        Write-Success ".env file created. Please review and modify as needed."
        Write-Warning "You may want to edit .env to choose your preferred embedding model."
    }
    else {
        Write-Status ".env file already exists, skipping creation."
    }
}

# Function to start services
function Start-Services {
    Write-Status "Starting Docker services..."
    
    # Pull images first
    Write-Status "Pulling Docker images..."
    & $script:ComposeCommand pull
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to pull Docker images"
        exit 1
    }
    
    # Start services
    Write-Status "Starting services in detached mode..."
    & $script:ComposeCommand up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start services"
        exit 1
    }
    
    Write-Success "Services started successfully"
}

# Function to wait for services to be healthy
function Wait-ForServices {
    Write-Status "Waiting for services to become healthy..."
    
    # Wait for Qdrant
    Write-Status "Checking Qdrant health..."
    $qdrantHealthy = $false
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:6333/health" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Success "Qdrant is healthy"
                $qdrantHealthy = $true
                break
            }
        }
        catch {
            # Continue waiting
        }
        
        if ($i -eq 30) {
            Write-Error "Qdrant failed to become healthy"
            exit 1
        }
        Start-Sleep -Seconds 2
    }
    
    # Wait for Ollama
    Write-Status "Checking Ollama health..."
    $ollamaHealthy = $false
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Success "Ollama is healthy"
                $ollamaHealthy = $true
                break
            }
        }
        catch {
            # Continue waiting
        }
        
        if ($i -eq 30) {
            Write-Error "Ollama failed to become healthy"
            exit 1
        }
        Start-Sleep -Seconds 2
    }
}

# Function to pull embedding model
function Get-EmbeddingModel {
    # Load environment variables
    $model = "nomic-embed-text"  # default
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        $modelLine = $envContent | Where-Object { $_ -match "^EMBEDDING_MODEL=(.+)$" }
        if ($modelLine) {
            $model = $matches[1]
        }
    }
    
    Write-Status "Pulling embedding model: $model"
    Write-Warning "This may take several minutes depending on your internet connection..."
    
    # Pull the model using Ollama API
    try {
        docker exec roo-ollama ollama pull $model
        if ($LASTEXITCODE -ne 0) {
            throw "Docker exec failed"
        }
    }
    catch {
        Write-Error "Failed to pull embedding model: $model"
        Write-Error "Please check your internet connection and try again"
        exit 1
    }
    
    Write-Success "Embedding model $model pulled successfully"
}

# Function to verify setup
function Test-Setup {
    Write-Status "Verifying setup..."
    
    # Check if services are running
    $qdrantRunning = docker ps --filter "name=roo-qdrant" --format "{{.Names}}" | Select-String "roo-qdrant"
    $ollamaRunning = docker ps --filter "name=roo-ollama" --format "{{.Names}}" | Select-String "roo-ollama"
    
    if (-not $qdrantRunning) {
        Write-Error "Qdrant container is not running"
        return $false
    }
    
    if (-not $ollamaRunning) {
        Write-Error "Ollama container is not running"
        return $false
    }
    
    # Check if model is available
    $model = "nomic-embed-text"  # default
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        $modelLine = $envContent | Where-Object { $_ -match "^EMBEDDING_MODEL=(.+)$" }
        if ($modelLine) {
            $model = $matches[1]
        }
    }
    
    try {
        $modelList = docker exec roo-ollama ollama list
        if (-not ($modelList | Select-String $model)) {
            Write-Warning "Embedding model $model not found in Ollama"
            return $false
        }
    }
    catch {
        Write-Warning "Could not verify embedding model"
        return $false
    }
    
    Write-Success "Setup verification completed successfully"
    return $true
}

# Function to display status
function Show-Status {
    Write-Host ""
    Write-Success "=== Roo Code Indexing Setup Complete ==="
    Write-Host ""
    Write-Host "Services:" -ForegroundColor Cyan
    Write-Host "  • Qdrant: http://localhost:6333" -ForegroundColor White
    Write-Host "  • Ollama: http://localhost:11434" -ForegroundColor White
    Write-Host ""
    Write-Host "Data directories:" -ForegroundColor Cyan
    
    $qdrantDir = ".\data\qdrant"
    $ollamaDir = ".\data\ollama"
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        $qdrantLine = $envContent | Where-Object { $_ -match "^QDRANT_STORAGE_PATH=(.+)$" }
        $ollamaLine = $envContent | Where-Object { $_ -match "^OLLAMA_MODELS_PATH=(.+)$" }
        if ($qdrantLine) { $qdrantDir = $matches[1] }
        if ($ollamaLine) { $ollamaDir = $matches[1] }
    }
    
    Write-Host "  • Qdrant: $qdrantDir" -ForegroundColor White
    Write-Host "  • Ollama: $ollamaDir" -ForegroundColor White
    Write-Host ""
    Write-Host "Management commands:" -ForegroundColor Cyan
    Write-Host "  • Stop services: $script:ComposeCommand down" -ForegroundColor White
    Write-Host "  • View logs: $script:ComposeCommand logs -f" -ForegroundColor White
    Write-Host "  • Restart: $script:ComposeCommand restart" -ForegroundColor White
    Write-Host ""
}

# Function to show help
function Show-Help {
    Write-Host "Roo Code Indexing Docker Setup for Windows" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\setup.ps1 [OPTIONS]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -Help          Show this help message" -ForegroundColor White
    Write-Host "  -Verify        Only verify the current setup" -ForegroundColor White
    Write-Host "  -PullModel     Only pull the embedding model" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1                 # Full setup" -ForegroundColor White
    Write-Host "  .\setup.ps1 -Verify         # Verify current setup" -ForegroundColor White
    Write-Host "  .\setup.ps1 -PullModel      # Pull embedding model only" -ForegroundColor White
    Write-Host ""
}

# Main execution function
function Invoke-Main {
    Write-Host "=== Roo Code Indexing Docker Setup ===" -ForegroundColor Green
    Write-Host ""
    
    Test-Requirements
    Initialize-EnvFile
    New-DataDirectories
    Start-Services
    Wait-ForServices
    
    # Try to pull the embedding model
    try {
        Get-EmbeddingModel
        if (Test-Setup) {
            Show-Status
        }
        else {
            Write-Warning "Setup completed but verification had issues. Please check the logs."
        }
    }
    catch {
        Write-Warning "Setup completed but failed to pull embedding model. You can pull it manually later."
        Show-Status
    }
}

# Handle script parameters
if ($Help) {
    Show-Help
    exit 0
}
elseif ($Verify) {
    Test-Requirements
    $result = Test-Setup
    exit $(if ($result) { 0 } else { 1 })
}
elseif ($PullModel) {
    Test-Requirements
    Get-EmbeddingModel
    exit 0
}
else {
    Invoke-Main
}