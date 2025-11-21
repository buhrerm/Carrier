# CLAUDE.md - AI Assistant Guidelines

## 🎯 PROJECT GOAL

**This platform has ONE specific purpose:**
> Deploy and manage multiple applications on a VPS, where each application consists of multiple Docker Compose services (frontend, backend, database). All management happens through Portainer's web UI with GitHub integration for automatic deployments.

### Core Requirements
1. **Multiple Apps**: Support unlimited applications on one VPS
2. **Docker Compose Native**: Each app defined by docker-compose.yml files
3. **Multi-Service Apps**: Each app has frontend, backend, database, cache, etc.
4. **UI Management**: Everything managed through Portainer web interface
5. **GitHub Integration**: Deploy from GitHub repositories via webhooks
6. **Container Visibility**: See health, logs, and status of all containers
7. **Zero-Downtime Deploys**: Update apps without downtime

### What This Is NOT
- ❌ NOT a generic PaaS platform
- ❌ NOT trying to be Vercel/Netlify
- ❌ NOT for single-container apps
- ❌ NOT for users who don't know Docker Compose
- ❌ NOT offering multiple installation options

---

## 📁 Project Structure

```
docker-compose-vps/
├── install.sh              # One-command installation
├── config/                 # Platform configuration
│   ├── traefik/           # Reverse proxy config
│   ├── portainer/         # Portainer settings
│   └── environment/       # Environment templates
├── scripts/               # Management scripts
│   ├── backup.sh         # Backup all apps
│   ├── restore.sh        # Restore from backup
│   └── health-check.sh   # Monitor all services
├── apps/                  # Deployed applications (git-ignored)
│   ├── app1/             # Each app gets a directory
│   │   ├── docker-compose.yml
│   │   └── .env
│   └── app2/
├── templates/            # Docker Compose templates
│   ├── fullstack-node/  # Node.js full-stack template
│   ├── fullstack-python/# Python full-stack template
│   └── microservices/   # Microservices template
├── docs/                 # Documentation
│   ├── deployment.md    # How to deploy apps
│   ├── networking.md    # Internal networking setup
│   └── troubleshooting.md
├── .env.example         # Platform environment template
├── docker-compose.yml   # Main platform stack
└── README.md           # User documentation
```

---

## 🏗 Architecture

### Platform Stack (docker-compose.yml)
```yaml
services:
  traefik:      # Reverse proxy, SSL, routing
  portainer:    # Docker management UI
  postgres:     # Shared database server (optional)
  redis:        # Shared cache (optional)
  webhook:      # GitHub webhook receiver
```

### App Structure
Each app in `apps/` directory:
```yaml
# apps/myapp/docker-compose.yml
services:
  frontend:     # React/Vue/Angular
  backend:      # API service
  database:     # PostgreSQL/MySQL
  cache:        # Redis/Memcached
  worker:       # Background jobs
```

---

## 💻 Technical Decisions

### Why This Architecture?

1. **Portainer**: Industry-standard Docker management UI
2. **Traefik**: Best Docker-native reverse proxy
3. **Docker Compose**: Standard for multi-container apps
4. **GitHub Webhooks**: Simple CI/CD without complexity

### Network Architecture
```
External Traffic
    ↓
[Traefik] (ports 80/443)
    ↓
[Web Network] (reverse proxy)
    ↓
[App Containers]
    ↓
[Internal Network] (databases)
```

### Deployment Flow
```
1. Developer pushes to GitHub
2. GitHub webhook → VPS
3. Pull docker-compose.yml
4. docker-compose up -d
5. Traefik auto-configures routing
6. App live with SSL
```

---

## 🛠 Development Guidelines

### When Adding Features

#### ✅ DO:
- Keep everything docker-compose native
- Use Portainer API when possible
- Maintain single-purpose scripts
- Use environment variables for config
- Document in terms of docker-compose

#### ❌ DON'T:
- Add alternative platforms (no Coolify, Dokku, etc.)
- Create abstractions over docker-compose
- Hide Docker complexity - users should understand it
- Add features unrelated to multi-app management
- Support non-compose deployment methods

### Script Standards

Every script should:
```bash
#!/bin/bash
set -e

# Load configuration
source /opt/docker-platform/config/env.sh

# Single purpose
main() {
    validate_environment
    perform_task
    report_status
}

main "$@"
```

### Docker Compose Labels

All apps must use these Traefik labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.${APP_NAME}.rule=Host(`${APP_DOMAIN}`)"
  - "traefik.http.routers.${APP_NAME}.tls=true"
  - "traefik.http.routers.${APP_NAME}.tls.certresolver=letsencrypt"
```

---

## 📝 App Deployment Checklist

When deploying a new app:

1. **Repository Structure**
   ```
   repo/
   ├── docker-compose.yml      # Required
   ├── docker-compose.prod.yml # Optional overrides
   ├── .env.example           # Required
   └── README.md              # Required
   ```

2. **Docker Compose Requirements**
   - Use version 3.8+
   - Include health checks
   - Set resource limits
   - Use named volumes
   - Configure restart policies

3. **Network Configuration**
   - Frontend/API on `web` network
   - Databases on `internal` network
   - No exposed ports (Traefik handles this)

4. **Environment Variables**
   - Never hardcode secrets
   - Use `.env` files
   - Document all variables

---

## 🚨 Common Patterns

### Full-Stack App Template
```yaml
version: '3.8'

networks:
  web:
    external: true
  internal:
    external: true

services:
  frontend:
    build: ./frontend
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.domain.com`)"
    depends_on:
      - backend

  backend:
    build: ./backend
    networks:
      - web
      - internal
    environment:
      - DATABASE_URL=postgresql://...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.app.domain.com`)"

  database:
    image: postgres:15
    networks:
      - internal
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

### Microservices Template
```yaml
version: '3.8'

services:
  gateway:
    # API Gateway

  service-a:
    # Microservice A

  service-b:
    # Microservice B

  message-queue:
    # RabbitMQ/Kafka

  cache:
    # Redis
```

---

## 🔧 Maintenance Tasks

### Daily
- Check Portainer dashboard for unhealthy containers
- Review resource usage

### Weekly
- Run backup script
- Check for Docker image updates
- Review logs for errors

### Monthly
- Update platform components
- Clean unused images/volumes
- Review and rotate secrets

---

## 📊 Monitoring

Key metrics to track:
- Container health status
- Memory usage per app
- CPU usage per app
- Disk usage
- Network traffic
- SSL certificate expiry

---

## 🚀 Future Considerations

Potential improvements (maintain focus):
- Prometheus + Grafana for metrics
- Automated testing before deployment
- Blue-green deployments
- Database backup automation
- Log aggregation with Loki

---

## ⚠️ Critical Rules

1. **One Platform**: Only Portainer + Traefik, no alternatives
2. **Compose Native**: Everything uses docker-compose.yml
3. **UI First**: All management through Portainer UI
4. **GitHub Source**: Apps deploy from GitHub repos
5. **Multi-Service**: Built for apps with multiple containers
6. **No Abstractions**: Direct Docker Compose, no wrappers

---

## 📌 Remember

**Every decision should answer: "Does this help manage multiple docker-compose applications through a UI?"**

If not, it doesn't belong in this project.