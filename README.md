# Docker Compose Multi-App VPS Platform

**Purpose**: Deploy and manage multiple docker-compose applications on a single VPS through Portainer's web UI with GitHub auto-deployment.

## 🎯 What This Does

- **Manages multiple applications** each with their own docker-compose.yml
- **Each app can have** frontend, backend, database, cache, workers
- **Everything controlled** through Portainer's web interface
- **Auto-deploys** from GitHub on push
- **Automatic SSL** certificates for all domains
- **Zero-downtime** deployments

## 🚀 Quick Start

```bash
# SSH into your VPS
ssh root@your-vps-ip

# Clone and install
git clone https://github.com/yourusername/docker-compose-vps.git
cd docker-compose-vps
sudo ./install.sh

# Configure
nano /opt/docker-platform/.env

# Restart services
cd /opt/docker-platform
docker compose restart
```

## 📋 Requirements

- Ubuntu 22.04/24.04 or Debian 11/12
- 2GB RAM minimum (4GB recommended)
- 30GB disk space
- Domain name with DNS control
- Cloudflare account (free tier works)

## 🏗️ Architecture

```
Your VPS
├── Traefik (Reverse Proxy - handles all domains/SSL)
├── Portainer (Docker Management UI)
├── Webhook Handler (GitHub auto-deploy)
└── Your Apps
    ├── app1/
    │   ├── frontend container
    │   ├── backend container
    │   └── postgres container
    ├── app2/
    │   ├── web container
    │   ├── api container
    │   ├── postgres container
    │   └── redis container
    └── app3/
        └── ... more containers
```

## 🔧 Configuration

### 1. Domain Setup

Edit `/opt/docker-platform/.env`:
```env
DOMAIN=yourdomain.com
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_TOKEN=your-token
```

### 2. DNS Records

Point these to your VPS IP:
```
A    *.yourdomain.com    →    YOUR_VPS_IP
A    yourdomain.com       →    YOUR_VPS_IP
```

### 3. Cloudflare API Token

1. Go to Cloudflare → My Profile → API Tokens
2. Create Token → Edit zone DNS
3. Permissions: Zone:DNS:Edit
4. Zone Resources: Include → Your domain

## 📦 Deploying Applications

### Method 1: Through Portainer UI (Recommended)

1. Access `https://portainer.yourdomain.com`
2. Go to **Stacks** → **Add Stack**
3. Choose **Git Repository**
4. Enter your repo URL with docker-compose.yml
5. Configure environment variables
6. Deploy

### Method 2: GitHub Auto-Deploy

1. In your GitHub repo, add webhook:
   - URL: `https://webhook.yourdomain.com/hooks/deploy-app`
   - Content type: `application/json`
   - Events: Push events

2. Your repo must have:
   ```
   docker-compose.yml
   .env.production (or .env.example)
   ```

3. Push to main branch → Auto deploys!

### Method 3: Manual Deployment

```bash
cd /opt/docker-platform/apps/myapp
git clone https://github.com/you/myapp.git .
docker compose up -d
```

## 📁 Application Structure

Your application repository should look like:

```
myapp/
├── docker-compose.yml    # Required: Defines all services
├── .env.example         # Required: Environment template
├── frontend/           # Frontend code
│   └── Dockerfile
├── backend/            # Backend code
│   └── Dockerfile
└── README.md          # Documentation
```

### Example docker-compose.yml

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
      - "traefik.http.routers.myapp.rule=Host(`myapp.com`)"
      - "traefik.http.routers.myapp.tls=true"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"

  backend:
    build: ./backend
    networks:
      - web
      - internal
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-api.rule=Host(`api.myapp.com`)"
      - "traefik.http.routers.myapp-api.tls=true"
      - "traefik.http.routers.myapp-api.tls.certresolver=cloudflare"

  db:
    image: postgres:15
    networks:
      - internal
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - ./data:/var/lib/postgresql/data
```

## 🎛️ Managing Applications

### View All Containers
1. Open Portainer: `https://portainer.yourdomain.com`
2. Click **Containers** to see all running services
3. View logs, restart, or exec into any container

### Update an Application
```bash
cd /opt/docker-platform/apps/myapp
git pull
docker compose up -d --build
```

### Stop an Application
```bash
cd /opt/docker-platform/apps/myapp
docker compose down
```

### Remove an Application
```bash
cd /opt/docker-platform/apps/myapp
docker compose down -v  # Also removes volumes
cd ..
rm -rf myapp
```

## 🔍 Monitoring

### Check Platform Status
```bash
docker ps
```

### View Logs
```bash
# Platform logs
docker logs traefik
docker logs portainer

# App logs
docker logs myapp-frontend
docker logs myapp-backend
```

### Resource Usage
```bash
docker stats
```

## 🛡️ Security

### Automatic Security Features
- ✅ SSL certificates auto-generated
- ✅ Databases not exposed to internet
- ✅ Containers isolated by networks
- ✅ Automatic security updates available

### Manual Security Steps
1. Change default passwords in `.env`
2. Set up Portainer admin account immediately
3. Configure firewall (done by installer)
4. Regular backups (see below)

## 💾 Backup

### Backup All Apps
```bash
#!/bin/bash
# backup.sh
BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup all app data
for app in /opt/docker-platform/apps/*; do
  app_name=$(basename $app)
  docker compose -f $app/docker-compose.yml down
  tar -czf $BACKUP_DIR/${app_name}.tar.gz $app
  docker compose -f $app/docker-compose.yml up -d
done

# Backup Portainer data
docker run --rm -v portainer_data:/data -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/portainer.tar.gz /data
```

## 🚨 Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs container-name

# Check compose file
docker compose config

# Validate syntax
docker compose -f docker-compose.yml config
```

### SSL Certificate Issues
```bash
# Check Traefik logs
docker logs traefik

# Verify Cloudflare token
# Ensure DNS points to server
```

### Port Conflicts
```bash
# Find what's using a port
sudo lsof -i :80
sudo lsof -i :443
```

### Disk Space Issues
```bash
# Clean up Docker
docker system prune -a
docker volume prune
```

## 📊 Example Deployments

### WordPress Site
```yaml
services:
  wordpress:
    image: wordpress
    networks: [web, internal]
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_PASSWORD: secret

  mysql:
    image: mysql:8
    networks: [internal]
    environment:
      MYSQL_ROOT_PASSWORD: secret
```

### Python FastAPI + PostgreSQL
```yaml
services:
  api:
    build: .
    networks: [web, internal]
    environment:
      DATABASE_URL: postgresql://user:pass@postgres/db

  postgres:
    image: postgres:15
    networks: [internal]
```

### Microservices Architecture
```yaml
services:
  gateway:
    build: ./gateway
    networks: [web, internal]

  service1:
    build: ./service1
    networks: [internal]

  service2:
    build: ./service2
    networks: [internal]

  rabbitmq:
    image: rabbitmq:3-management
    networks: [internal]
```

## 💰 Cost Comparison

| Provider | 5 Apps | 10 Apps | 15 Apps |
|----------|--------|---------|---------|
| Heroku | $35/mo | $70/mo | $105/mo |
| Render | $35/mo | $70/mo | $105/mo |
| Railway | $25/mo | $50/mo | $75/mo |
| **Your VPS** | **$10/mo** | **$20/mo** | **$40/mo** |

## 📚 Templates

Ready-to-use templates in `/templates/`:
- `fullstack-node/` - Node.js + React + PostgreSQL + Redis
- `fullstack-python/` - Python + Vue + PostgreSQL + Celery
- `microservices/` - Multi-service architecture template

## 🆘 Support

- Check `CLAUDE.md` for AI assistant guidelines
- Review `docs/` folder for detailed guides
- GitHub Issues for bug reports

## 📄 License

MIT - Use freely for personal and commercial projects

---

**Remember**: This platform is designed specifically for managing multiple docker-compose applications. Each app should be a complete stack defined in its own docker-compose.yml file.