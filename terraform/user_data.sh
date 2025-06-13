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

# Set database environment variables
export DB_ENDPOINT="${db_endpoint}"
export DB_NAME="${db_name}"
export DB_USERNAME="${db_username}"
export DB_PASSWORD="${db_password}"

# Create environment file for Docker
cat > .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://$${DB_USERNAME}:$${DB_PASSWORD}@$${DB_ENDPOINT}/$${DB_NAME}?sslmode=disable
DB_PASSWORD=$${DB_PASSWORD}
EOF

# Create docker-compose file for production
cat > docker-compose.prod.yml << "EOF"
version: '3.8'

services:
  app:
    image: ghcr.io/jakepage91/magic-eight-ball:latest
    ports:
      - "80:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=$${DATABASE_URL}
    restart: unless-stopped
    networks:
      - magic8ball-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  magic8ball-network:
    driver: bridge
EOF

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