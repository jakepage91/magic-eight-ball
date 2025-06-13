#!/bin/bash
set -e

# Update the system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install SSM agent (should already be installed on Amazon Linux 2)
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Create application directory
mkdir -p /opt/magic8ball
cd /opt/magic8ball

# Get the public IP address for traefik.me domain
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Set database environment variables
export DB_ENDPOINT="${db_endpoint}"
export DB_NAME="${db_name}"
export DB_USERNAME="${db_username}"
export DB_PASSWORD="${db_password}"

# Create environment file for Docker
cat > .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://$${DB_USERNAME}:$${DB_PASSWORD}@$${DB_ENDPOINT}:5432/$${DB_NAME}
DB_PASSWORD=$${DB_PASSWORD}
EOF

# Create docker-compose file for production
cat > docker-compose.prod.yml << "EOF"
version: '3.8'

services:
  app:
    image: ghcr.io/jakepage/magic-eight-ball:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=$${DATABASE_URL}
    restart: unless-stopped
    depends_on:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.magic8ball.rule=Host(\`magic8ball.PUBLIC_IP_PLACEHOLDER.traefik.me\`)"
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
      - "--certificatesresolvers.myresolver.acme.email=jakepage@gmail.com"
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
      - "traefik.http.routers.traefik.rule=Host(\`traefik.PUBLIC_IP_PLACEHOLDER.traefik.me\`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=myresolver"
      - "traefik.http.routers.traefik.service=api@internal"

networks:
  traefik-network:
    driver: bridge

volumes:
  letsencrypt_data:
EOF

# Replace placeholder with actual IP
sed -i "s/PUBLIC_IP_PLACEHOLDER/$${PUBLIC_IP}/g" docker-compose.prod.yml

# Create systemd service for the application
cat > /etc/systemd/system/magic8ball.service << "EOF"
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

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable magic8ball.service

# Create a script to wait for RDS to be available
cat > /opt/magic8ball/wait-for-db.sh << "EOF"
#!/bin/bash
echo "Waiting for database to be available..."
until timeout 1 bash -c "</dev/tcp/$${DB_ENDPOINT%:*}/5432" 2>/dev/null; do
  echo "Database not ready, waiting..."
  sleep 5
done
echo "Database is ready!"
EOF

chmod +x /opt/magic8ball/wait-for-db.sh

# Wait for database and start services
/opt/magic8ball/wait-for-db.sh
systemctl start magic8ball.service

# Setup log rotation
cat > /etc/logrotate.d/magic8ball << "EOF"
/var/log/magic8ball/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# Create cron job for health checks
echo "*/5 * * * * root curl -f http://localhost:3000/health || systemctl restart magic8ball.service" >> /etc/crontab

echo "Setup complete!" 