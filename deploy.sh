#!/bin/bash
set -e

# Magic Eight Ball Deployment Script
# This script is used by the CI/CD pipeline to deploy the application

IMAGE_TAG=${1:-latest}
GITHUB_TOKEN=${2:-}
GITHUB_ACTOR=${3:-}

echo "🎱 Starting Magic Eight Ball deployment..."
echo "Image tag: $IMAGE_TAG"

# Update system packages
echo "📦 Updating system packages..."
sudo yum update -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker ec2-user
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "🔧 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already installed"
fi

# Create application directory
sudo mkdir -p /opt/magic8ball
cd /opt/magic8ball

# Login to GitHub Container Registry if credentials provided
if [ ! -z "$GITHUB_TOKEN" ] && [ ! -z "$GITHUB_ACTOR" ]; then
    echo "🔑 Logging into GitHub Container Registry..."
    echo "$GITHUB_TOKEN" | sudo docker login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
    echo "✅ Successfully logged into GitHub Container Registry"
fi

# Pull the latest image
echo "📥 Pulling Docker image: $IMAGE_TAG"
sudo docker pull "$IMAGE_TAG"

# Stop existing containers gracefully
echo "🛑 Stopping existing containers..."
sudo docker-compose -f docker-compose.prod.yml down --remove-orphans || true

# Create production docker-compose file
echo "📝 Creating production docker-compose configuration..."
cat > docker-compose.prod.yml << EOF
version: '3.8'

services:
  app:
    image: $IMAGE_TAG
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=\${DATABASE_URL}
    restart: unless-stopped
    depends_on:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.magic8ball.rule=Host(\`magic8ball.traefik.me\`)"
      - "traefik.http.routers.magic8ball.entrypoints=websecure"
      - "traefik.http.routers.magic8ball.tls.certresolver=myresolver"
      - "traefik.http.services.magic8ball.loadbalancer.server.port=3000"
    networks:
      - traefik-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  traefik:
    image: traefik:v3.0
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=demo@example.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      - "--global.sendanonymoususage=false"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    restart: unless-stopped
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.traefik.me\`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=myresolver"
      - "traefik.http.routers.traefik.service=api@internal"

networks:
  traefik-network:
    driver: bridge

volumes:
  letsencrypt_data:
EOF

# Create systemd service file
echo "🔧 Setting up systemd service..."
sudo tee /etc/systemd/system/magic8ball.service > /dev/null << EOF
[Unit]
Description=Magic 8-Ball Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/magic8ball
ExecStart=/usr/local/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=300
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable magic8ball.service

# Wait for database connectivity (if DATABASE_URL is set)
if [ ! -z "$DATABASE_URL" ]; then
    echo "🔍 Waiting for database connectivity..."
    DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    
    if [ ! -z "$DB_HOST" ] && [ ! -z "$DB_PORT" ]; then
        echo "Testing connection to $DB_HOST:$DB_PORT..."
        for i in {1..30}; do
            if timeout 5 bash -c "</dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
                echo "✅ Database is accessible!"
                break
            else
                echo "⏳ Waiting for database... (attempt $i/30)"
                sleep 10
            fi
        done
    fi
fi

# Start the application
echo "🚀 Starting Magic Eight Ball application..."
sudo systemctl start magic8ball.service

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Check service status
if sudo systemctl is-active --quiet magic8ball.service; then
    echo "✅ Magic Eight Ball service is running!"
else
    echo "❌ Failed to start Magic Eight Ball service"
    sudo systemctl status magic8ball.service
    exit 1
fi

# Test application health
echo "🏥 Testing application health..."
for i in {1..12}; do
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        echo "✅ Application is healthy and responding!"
        break
    else
        echo "⏳ Waiting for application to be ready... (attempt $i/12)"
        sleep 10
    fi
done

# Final health check
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo "📱 Application: https://magic8ball.traefik.me"
    echo "🎛️  Traefik Dashboard: https://traefik.traefik.me"
    echo ""
    echo "📊 Service Status:"
    sudo systemctl status magic8ball.service --no-pager
    echo ""
    echo "🐳 Container Status:"
    sudo docker-compose -f docker-compose.prod.yml ps
else
    echo "❌ Application health check failed!"
    echo "📋 Application logs:"
    sudo docker-compose -f docker-compose.prod.yml logs app --tail=50
    exit 1
fi

# Clean up old Docker images to save space
echo "🧹 Cleaning up old Docker images..."
sudo docker system prune -f --volumes

echo "✨ Deployment script completed successfully!" 