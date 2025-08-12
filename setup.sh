#!/bin/bash

# Roo Code Indexing Docker Setup Script
# This script automates the initial setup of Qdrant and Ollama services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if Docker is installed
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check available memory
    if command_exists free; then
        TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt 16 ]; then
            print_warning "System has less than 16GB RAM. Consider using nomic-embed-text model."
        fi
    fi
    
    print_success "System requirements check passed"
}

# Function to create necessary directories
create_directories() {
    print_status "Creating data directories..."
    
    # Load environment variables if .env exists
    if [ -f .env ]; then
        source .env
    fi
    
    # Create directories with defaults
    QDRANT_DIR="${QDRANT_STORAGE_PATH:-./data/qdrant}"
    OLLAMA_DIR="${OLLAMA_MODELS_PATH:-./data/ollama}"
    
    mkdir -p "$QDRANT_DIR"
    mkdir -p "$OLLAMA_DIR"
    
    # Set proper permissions
    chmod 755 "$QDRANT_DIR"
    chmod 755 "$OLLAMA_DIR"
    
    print_success "Data directories created: $QDRANT_DIR, $OLLAMA_DIR"
}

# Function to create .env file if it doesn't exist
setup_env_file() {
    if [ ! -f .env ]; then
        print_status "Creating .env file from template..."
        cp .env.example .env
        print_success ".env file created. Please review and modify as needed."
        print_warning "You may want to edit .env to choose your preferred embedding model."
    else
        print_status ".env file already exists, skipping creation."
    fi
}

# Function to start services
start_services() {
    print_status "Starting Docker services..."
    
    # Use docker-compose or docker compose based on availability
    if command_exists docker-compose; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Pull images first
    print_status "Pulling Docker images..."
    $COMPOSE_CMD pull
    
    # Start services
    print_status "Starting services in detached mode..."
    $COMPOSE_CMD up -d
    
    print_success "Services started successfully"
}

# Function to wait for services to be healthy
wait_for_services() {
    print_status "Waiting for services to become healthy..."
    
    # Wait for Qdrant
    print_status "Checking Qdrant health..."
    for i in {1..30}; do
        if curl -s http://localhost:6333/readyz >/dev/null 2>&1; then
            print_success "Qdrant is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Qdrant failed to become healthy"
            exit 1
        fi
        sleep 2
    done
    
    # Wait for Ollama
    print_status "Checking Ollama health..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            print_success "Ollama is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Ollama failed to become healthy"
            exit 1
        fi
        sleep 2
    done
}

# Function to pull embedding model
pull_embedding_model() {
    # Load environment variables
    if [ -f .env ]; then
        source .env
    fi
    
    MODEL="${EMBEDDING_MODEL:-nomic-embed-text}"
    
    print_status "Pulling embedding model: $MODEL"
    print_warning "This may take several minutes depending on your internet connection..."
    
    # Pull the model using Ollama API
    if ! docker exec roo-ollama ollama pull "$MODEL"; then
        print_error "Failed to pull embedding model: $MODEL"
        print_error "Please check your internet connection and try again"
        exit 1
    fi
    
    print_success "Embedding model $MODEL pulled successfully"
}

# Function to verify setup
verify_setup() {
    print_status "Verifying setup..."
    
    # Check if services are running
    if ! docker ps | grep -q roo-qdrant; then
        print_error "Qdrant container is not running"
        exit 1
    fi
    
    if ! docker ps | grep -q roo-ollama; then
        print_error "Ollama container is not running"
        exit 1
    fi
    
    # Check if model is available
    if [ -f .env ]; then
        source .env
    fi
    MODEL="${EMBEDDING_MODEL:-nomic-embed-text}"
    
    if ! docker exec roo-ollama ollama list | grep -q "$MODEL"; then
        print_warning "Embedding model $MODEL not found in Ollama"
        return 1
    fi
    
    print_success "Setup verification completed successfully"
    return 0
}

# Function to display status
show_status() {
    echo
    print_success "=== Roo Code Indexing Setup Complete ==="
    echo
    echo "Services:"
    echo "  • Qdrant: http://localhost:6333"
    echo "  • Ollama: http://localhost:11434"
    echo
    echo "Data directories:"
    if [ -f .env ]; then
        source .env
    fi
    echo "  • Qdrant: ${QDRANT_STORAGE_PATH:-./data/qdrant}"
    echo "  • Ollama: ${OLLAMA_MODELS_PATH:-./data/ollama}"
    echo
    echo "To stop services: docker-compose down"
    echo "To view logs: docker-compose logs -f"
    echo "To restart: docker-compose restart"
    echo
}

# Main execution
main() {
    echo "=== Roo Code Indexing Docker Setup ==="
    echo
    
    check_requirements
    setup_env_file
    create_directories
    start_services
    wait_for_services
    
    # Try to pull the embedding model
    if pull_embedding_model; then
        if verify_setup; then
            show_status
        else
            print_warning "Setup completed but verification had issues. Please check the logs."
        fi
    else
        print_warning "Setup completed but failed to pull embedding model. You can pull it manually later."
        show_status
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --verify       Only verify the current setup"
        echo "  --pull-model   Only pull the embedding model"
        echo
        exit 0
        ;;
    --verify)
        verify_setup
        exit $?
        ;;
    --pull-model)
        pull_embedding_model
        exit $?
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac