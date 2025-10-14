#!/bin/bash

# Apache Sedona Docker Helper Script
# This script provides convenient commands for managing the Sedona environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo -e "${BLUE}Apache Sedona Docker Management Script${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start         Start all services (master, worker, jupyter)"
    echo "  stop          Stop all services"
    echo "  restart       Restart all services"
    echo "  build         Build/rebuild the Docker image"
    echo "  jupyter       Start only Jupyter notebook service"
    echo "  pyspark       Start interactive PySpark shell"
    echo "  shell         Start interactive Spark Scala shell"
    echo "  logs          View logs from all services"
    echo "  status        Show status of running services"
    echo "  clean         Stop services and remove containers"
    echo "  purge         Remove everything including images and volumes"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Start all services"
    echo "  $0 jupyter            # Start only Jupyter"
    echo "  $0 logs spark-master  # View master logs"
    echo "  $0 pyspark            # Interactive Python shell"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed or not in PATH${NC}"
        exit 1
    fi
}

start_services() {
    echo -e "${GREEN}Starting Apache Sedona services...${NC}"
    docker-compose up -d
    echo ""
    echo -e "${GREEN}Services started successfully!${NC}"
    echo -e "📊 Jupyter Notebook: ${BLUE}http://localhost:8888${NC}"
    echo -e "🔥 Spark Master UI: ${BLUE}http://localhost:8080${NC}"
    echo -e "⚙️  Spark Worker UI: ${BLUE}http://localhost:8081${NC}"
}

stop_services() {
    echo -e "${YELLOW}Stopping Apache Sedona services...${NC}"
    docker-compose down
    echo -e "${GREEN}Services stopped.${NC}"
}

restart_services() {
    echo -e "${YELLOW}Restarting Apache Sedona services...${NC}"
    docker-compose restart
    echo -e "${GREEN}Services restarted.${NC}"
}

build_image() {
    echo -e "${YELLOW}Building Apache Sedona Docker image...${NC}"
    docker-compose build --no-cache
    echo -e "${GREEN}Image built successfully.${NC}"
}

start_jupyter() {
    echo -e "${GREEN}Starting Jupyter Notebook service...${NC}"
    docker-compose up -d jupyter
    echo -e "📊 Jupyter Notebook: ${BLUE}http://localhost:8888${NC}"
}

start_pyspark() {
    echo -e "${GREEN}Starting interactive PySpark shell...${NC}"
    docker run --rm -it \
        -v "$(pwd)/data:/workspace/data" \
        -v "$(pwd)/notebooks:/workspace/notebooks" \
        --network apache-sedona_sedona-network \
        apache-sedona_pyspark pyspark
}

start_shell() {
    echo -e "${GREEN}Starting interactive Spark Shell...${NC}"
    docker run --rm -it \
        -v "$(pwd)/data:/workspace/data" \
        -v "$(pwd)/notebooks:/workspace/notebooks" \
        --network apache-sedona_sedona-network \
        apache-sedona_pyspark shell
}

view_logs() {
    if [ -n "$2" ]; then
        docker-compose logs -f "$2"
    else
        docker-compose logs -f
    fi
}

show_status() {
    echo -e "${BLUE}Service Status:${NC}"
    docker-compose ps
    echo ""
    echo -e "${BLUE}Running Containers:${NC}"
    docker ps --filter "label=com.docker.compose.project=apache-sedona"
}

clean_environment() {
    echo -e "${YELLOW}Cleaning up containers and networks...${NC}"
    docker-compose down --remove-orphans
    echo -e "${GREEN}Environment cleaned.${NC}"
}

purge_environment() {
    echo -e "${RED}WARNING: This will remove all containers, images, and volumes!${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Purging Apache Sedona environment...${NC}"
        docker-compose down --remove-orphans --volumes --rmi all
        echo -e "${GREEN}Environment purged.${NC}"
    else
        echo "Cancelled."
    fi
}

# Main script logic
check_docker

case "${1:-help}" in
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "build")
        build_image
        ;;
    "jupyter")
        start_jupyter
        ;;
    "pyspark")
        start_pyspark
        ;;
    "shell")
        start_shell
        ;;
    "logs")
        view_logs "$@"
        ;;
    "status")
        show_status
        ;;
    "clean")
        clean_environment
        ;;
    "purge")
        purge_environment
        ;;
    "help"|"--help"|"-h")
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac