#!/bin/bash
# Docker Compose VPS Platform - One-Command Installation

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
INSTALL_DIR="/opt/docker-platform"
MIN_RAM=2048
MIN_DISK=30

show_banner() {
    cat << "EOF"
╔════════════════════════════════════════════╗
║   Docker Compose Multi-App VPS Platform    ║
║   Portainer + Traefik + GitHub Integration ║
╚════════════════════════════════════════════╝
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_requirements() {
    log_info "Checking system requirements..."

    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi

    source /etc/os-release
    if [[ "${ID}" != "ubuntu" ]] && [[ "${ID}" != "debian" ]]; then
        log_warning "This script is tested on Ubuntu/Debian. Current OS: ${ID}"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check RAM
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt $MIN_RAM ]]; then
        log_warning "System has ${total_ram}MB RAM, recommended minimum is ${MIN_RAM}MB"
    fi

    # Check disk space
    local available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_disk -lt $MIN_DISK ]]; then
        log_warning "System has ${available_disk}GB available, recommended minimum is ${MIN_DISK}GB"
    fi
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker is already installed"
        return
    fi

    log_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh

    # Add current user to docker group
    if [[ -n "${SUDO_USER}" ]]; then
        usermod -aG docker "${SUDO_USER}"
    fi
}

install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        log_info "Docker Compose is already installed"
        return
    fi

    log_info "Installing Docker Compose..."
    apt-get update
    apt-get install -y docker-compose-plugin
}

configure_firewall() {
    log_info "Configuring firewall..."

    # Install ufw if not present
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get install -y ufw
    fi

    ufw allow 22/tcp   # SSH
    ufw allow 80/tcp   # HTTP
    ufw allow 443/tcp  # HTTPS
    ufw --force enable
}

setup_platform() {
    log_info "Setting up platform directory..."

    # Create installation directory
    mkdir -p "${INSTALL_DIR}"

    # Copy all files to installation directory
    cp -r ./* "${INSTALL_DIR}/"
    cd "${INSTALL_DIR}"

    # Create necessary directories
    mkdir -p apps config/traefik config/webhook data

    # Set up environment file
    if [[ ! -f .env ]]; then
        cp .env.example .env
        log_warning "Please edit ${INSTALL_DIR}/.env with your configuration"
    fi

    # Create Docker networks
    docker network create web 2>/dev/null || true
    docker network create internal 2>/dev/null || true
}

generate_configs() {
    log_info "Generating configuration files..."

    # Traefik configuration
    if [[ ! -f config/traefik/traefik.yml ]]; then
        cat > config/traefik/traefik.yml << 'EOF'
api:
  dashboard: true

entryPoints:
  http:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: https
          scheme: https
  https:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: web

certificatesResolvers:
  cloudflare:
    acme:
      email: ${CF_API_EMAIL}
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "1.0.0.1:53"

log:
  level: INFO

accessLog: {}
EOF
    fi

    # Webhook configuration
    if [[ ! -f config/webhook/hooks.json ]]; then
        cat > config/webhook/hooks.json << 'EOF'
[
  {
    "id": "deploy-app",
    "execute-command": "/scripts/deploy.sh",
    "pass-arguments-to-command": [
      {
        "source": "payload",
        "name": "repository.name"
      },
      {
        "source": "payload",
        "name": "ref"
      }
    ],
    "trigger-rule": {
      "and": [
        {
          "match": {
            "type": "value",
            "value": "refs/heads/main",
            "parameter": {
              "source": "payload",
              "name": "ref"
            }
          }
        }
      ]
    }
  }
]
EOF
    fi
}

start_platform() {
    log_info "Starting platform services..."

    cd "${INSTALL_DIR}"
    docker compose up -d

    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 10

    # Check service health
    local services=("traefik" "portainer" "webhook")
    for service in "${services[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
            log_info "✓ ${service} is running"
        else
            log_error "✗ ${service} failed to start"
        fi
    done
}

show_completion() {
    local domain=$(grep "^DOMAIN=" .env | cut -d'=' -f2)

    echo
    log_info "════════════════════════════════════════"
    log_info "Installation Complete!"
    log_info "════════════════════════════════════════"
    echo
    echo "Access your services:"
    echo "  Portainer: https://portainer.${domain}"
    echo "  Traefik:   https://traefik.${domain}"
    echo
    echo "Next steps:"
    echo "1. Edit configuration: nano ${INSTALL_DIR}/.env"
    echo "2. Set up DNS records pointing to this server"
    echo "3. Access Portainer and create admin account"
    echo "4. Deploy your first app!"
    echo
    echo "Deploy apps by:"
    echo "  - Using Portainer's Stack feature"
    echo "  - Pushing to GitHub (webhook auto-deploy)"
    echo "  - Placing docker-compose.yml in ${INSTALL_DIR}/apps/"
    echo
    echo "Documentation: ${INSTALL_DIR}/README.md"
}

main() {
    show_banner
    check_root
    check_requirements

    log_info "Starting installation..."

    install_docker
    install_docker_compose
    configure_firewall
    setup_platform
    generate_configs
    start_platform
    show_completion
}

# Run installation
main "$@"