# Getting Started - Local Development

Quick start guide for developing Carrier locally. Zero configuration needed.

## Prerequisites

- Docker & Docker Compose installed
- That's it

## 1. Start the Platform (2 commands)

```bash
# Create networks
docker network create web && docker network create internal

# Start platform
docker compose up -d
```

That's it. No configuration files needed for basic dev work.

## 2. Access Services

- **Traefik Dashboard**: http://localhost:8080
- **Portainer**: http://localhost:9000 (create admin account on first visit)

## 3. Deploy a Test App

```bash
# Create app directory
mkdir -p apps/myapp && cd apps/myapp

# Create a simple docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  web:
    external: true

services:
  app:
    image: nginx:alpine
    container_name: myapp
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.localhost`)"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"
EOF

# Start it
docker compose up -d
```

Visit: http://myapp.localhost

## 4. Deploy the Full-Stack Template

```bash
# Copy template
mkdir -p apps/fullstack && cd apps/fullstack
cp -r ../../templates/fullstack-node/docker-compose.yml .

# Minimal config
cat > .env << 'EOF'
APP_NAME=fullstack
APP_DOMAIN=app.localhost
DB_USER=postgres
DB_PASS=postgres
DB_NAME=myapp
JWT_SECRET=dev-secret-change-in-prod
EOF

# Note: Remove TLS labels from docker-compose.yml for local dev
sed -i '/tls/d' docker-compose.yml
sed -i 's/certresolver=cloudflare//' docker-compose.yml

# Start
docker compose up -d
```

Visit:
- Frontend: http://app.localhost
- API: http://api.app.localhost

## Common Commands

```bash
# View all containers
docker ps

# View logs
docker logs traefik
docker logs myapp

# Stop everything
docker compose down

# Stop and remove app
cd apps/myapp
docker compose down -v  # -v removes volumes too

# Restart platform
docker compose restart

# View resource usage
docker stats
```

## Project Structure While Developing

```
carrier/
├── docker-compose.yml       # Platform stack (you rarely touch this)
├── apps/                    # Your test apps go here
│   ├── myapp/
│   │   └── docker-compose.yml
│   └── another-app/
│       └── docker-compose.yml
├── templates/              # Copy these to start new apps
└── config/                 # Auto-generated, ignore
```

## Tips for Local Development

### 1. Use .localhost domains
They resolve to 127.0.0.1 automatically. No `/etc/hosts` editing needed.

### 2. Skip SSL locally
Remove these labels from your app's docker-compose.yml:
```yaml
# Remove these for local dev:
- "traefik.http.routers.X.tls=true"
- "traefik.http.routers.X.tls.certresolver=cloudflare"
```

### 3. Hot reload your app code
Mount your code as a volume:
```yaml
services:
  app:
    volumes:
      - ./src:/app/src  # Your code hot-reloads
```

### 4. Quick app template
Most minimal app possible:
```yaml
version: '3.8'
networks:
  web:
    external: true
services:
  app:
    image: your-image
    networks: [web]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.NAME.rule=Host(`NAME.localhost`)"
      - "traefik.http.services.NAME.loadbalancer.server.port=PORT"
```

### 5. Debug Traefik routing
```bash
# See all registered routes
docker logs traefik 2>&1 | grep -i "router"

# See all discovered containers
docker logs traefik 2>&1 | grep -i "provider"
```

### 6. Clean slate
```bash
# Nuclear option - remove everything
docker compose down -v
docker system prune -a
docker volume prune
cd apps && rm -rf */
```

## Troubleshooting

### "Network web not found"
```bash
docker network create web && docker network create internal
```

### "Port already in use"
Something else is using port 80/443/8080:
```bash
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :8080
```

### App not accessible
1. Check container is running: `docker ps`
2. Check Traefik sees it: `docker logs traefik | grep myapp`
3. Check labels are correct: `docker inspect myapp`
4. Try direct port: Add `ports: ["8080:80"]` to your service

### Database connection issues
Make sure backend is on both networks:
```yaml
services:
  backend:
    networks:
      - web      # For Traefik
      - internal # For database
  db:
    networks:
      - internal # Only internal, never exposed
```

## What's Different in Production?

Local dev vs production:

| Feature | Local | Production |
|---------|-------|------------|
| SSL | No | Yes (automatic) |
| Domains | .localhost | Real domains |
| Config | None needed | .env required |
| Firewall | None | UFW configured |
| Secrets | Hardcoded OK | Must use secrets |
| Resource limits | Optional | Recommended |

## Next Steps

1. **Modify templates**: Edit `templates/fullstack-node/` to fit your stack
2. **Test webhooks**: Use `ngrok` to expose localhost for GitHub webhooks
3. **Add monitoring**: Deploy Prometheus/Grafana as another app
4. **Build your app**: Create `apps/myproject/` with your actual code

## Development Workflow

```bash
# 1. Start platform once
docker compose up -d

# 2. Create new app
mkdir -p apps/newproject && cd apps/newproject
# ... create docker-compose.yml
docker compose up -d

# 3. Develop - containers are running, you edit code
# Your volumes are mounted, changes reflect immediately

# 4. Test changes
docker logs newproject-backend -f

# 5. Rebuild if Dockerfile changes
docker compose up -d --build

# 6. Clean up when done
docker compose down
```

## The Golden Rule

**Everything is just Docker Compose.**

If you know how to write a docker-compose.yml, you know how to use Carrier. There's no magic, no abstractions, no hidden configuration. Just put a docker-compose.yml in `apps/yourapp/` and run `docker compose up -d`.

---

**Need help?** Check `README.md` for full documentation or `CLAUDE.md` for project architecture.
