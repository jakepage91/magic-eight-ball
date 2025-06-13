# 🎱 Complete Deployment Walkthrough: From Code to Production

## Overview: The Big Picture

This document walks you through the entire journey of how code becomes a running application that users can access via a URL. While the containerization with Docker Compose is straightforward, the infrastructure provisioning and deployment flow can be complex. Let's break it down step by step.

## The Complete Architecture Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │  GitHub Actions │    │ GitHub Container│
│                 │───▶│     CI/CD       │───▶│    Registry     │
│  Source Code    │    │   Pipeline      │    │   (ghcr.io)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Traefik.me    │    │   AWS EC2       │    │   AWS RDS       │
│   DNS + SSL     │◀───│   Instance      │───▶│  PostgreSQL     │
│                 │    │  (Traefik)      │    │   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Phase 1: Infrastructure Setup (Terraform)

### 1.1 Terraform Creates the Foundation

When you run `terraform apply`, the system creates:

- **VPC with public/private subnets**
- **EC2 instance** (Amazon Linux 2)
- **RDS PostgreSQL database**
- **Security groups** for networking
- **IAM roles** for permissions

### 1.2 The Critical User Data Connection

Here's the key part! In `terraform/main.tf`, look at this section:

```hcl
user_data = base64encode(templatefile("${path.module}/user_data.sh", {
  db_endpoint = aws_db_instance.main.endpoint
  db_name     = aws_db_instance.main.db_name
  db_username = aws_db_instance.main.username
  db_password = var.db_password
}))
```

**What's happening:**
1. Terraform takes the `user_data.sh` script
2. It **injects** the database connection details as variables
3. It base64-encodes the whole script  
4. It passes this to AWS, which runs it when the EC2 instance boots

### 1.3 User Data Script: The Bootstrap Process

The `terraform/user_data.sh` script is like a "setup wizard" that runs once when your EC2 instance first starts:

#### Step 1: Install Required Software
```bash
# Install Docker & Docker Compose
yum install -y docker
systemctl start docker
systemctl enable docker

# Install AWS Systems Manager (for remote deployments)
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
```

#### Step 2: Configure Database Connection
```bash
# Use the variables Terraform injected
export DB_ENDPOINT="${db_endpoint}"     # e.g., magic8ball-db.xyz.us-east-1.rds.amazonaws.com
export DB_NAME="${db_name}"             # e.g., magic_eight_ball
export DB_USERNAME="${db_username}"     # e.g., magic8ball
export DB_PASSWORD="${db_password}"     # Your secure password

# Create environment file for Docker
cat > .env << EOF
NODE_ENV=production
DATABASE_URL=postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}:5432/${DB_NAME}
EOF
```

#### Step 3: Create Initial Docker Compose Configuration
```bash
# Get the server's public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create docker-compose.prod.yml with traefik.me domains
# This creates URLs like: magic8ball.1.2.3.4.traefik.me
```

#### Step 4: Create System Service
```bash
# Create systemd service for automatic startup
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

[Install]
WantedBy=multi-user.target
EOF

systemctl enable magic8ball.service
```

#### Step 5: Start Initial Application
```bash
# Wait for database to be ready, then start the app
./wait-for-db.sh
systemctl start magic8ball.service
```

## Phase 2: Code Changes & CI/CD Pipeline

### 2.1 GitHub Actions Workflow Stages

When you push code to the `main` branch, `.github/workflows/ci-cd.yml` triggers three jobs:

#### Test Job (Runs First)
```yaml
test:
  runs-on: ubuntu-latest
  services:
    postgres:  # Spins up test database
      image: postgres:15-alpine
```

**What happens:**
- Sets up PostgreSQL test database
- Installs dependencies with `npm ci`
- Runs test suite with `npm test`
- **If tests fail, pipeline stops here**

#### Build & Push Job (Runs After Tests Pass)
```yaml
build-and-push:
  needs: test  # Only runs if tests pass
  runs-on: ubuntu-latest
```

**What happens:**
- Builds Docker image using `Dockerfile`
- Creates multi-architecture images (amd64/arm64)
- Pushes to GitHub Container Registry (`ghcr.io`)
- Tags image with branch name and `latest`

#### Deploy Job (Production Only)
```yaml
deploy:
  needs: [test, build-and-push]
  if: github.ref == 'refs/heads/main'  # Only on main branch
```

### 2.2 Container Registry Connection

Your Docker image gets pushed to:
```
ghcr.io/your-username/magic-eight-ball:latest
```

This is a **public registry** that your EC2 instance can pull from.

## Phase 3: Deployment to Production

### 3.1 The Deployment Process

When the deploy job runs, here's the magic:

#### Step 1: Find Your EC2 Instance
```bash
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=magic8ball-server" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
```

#### Step 2: Create Deployment Script
The pipeline creates a script that will:
- Update Docker Compose file with new image
- Update traefik.me domains with correct IP
- Pull new image from registry
- Restart services

#### Step 3: Execute via AWS Systems Manager
```bash
COMMAND_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=magic8ball-server" \
  --parameters commands="..." \
  --output text)
```

**Key Insight:** The deployment doesn't SSH into the server. Instead, it uses AWS Systems Manager (SSM) to remotely execute commands securely.

### 3.2 What Happens on the EC2 Instance

When the SSM command executes, it runs this process:

```bash
# Navigate to app directory (created by user_data.sh)
cd /opt/magic8ball

# Stop currently running containers
sudo docker-compose -f docker-compose.prod.yml down

# Update compose file with new image
sudo sed -i "s|image: ghcr.io/jakepage91/magic-eight-ball:.*|image: $NEW_IMAGE_TAG|g" docker-compose.prod.yml

# Pull new image from GitHub Container Registry
sudo docker pull "$NEW_IMAGE_TAG"

# Start updated services
sudo docker-compose -f docker-compose.prod.yml up -d
```

## Phase 4: How the Application Becomes Accessible

### 4.1 Traefik: The Reverse Proxy Magic

Your `docker-compose.prod.yml` runs two main services:

1. **Your App** (`magic-eight-ball:latest`) - runs on port 3000 internally
2. **Traefik** - reverse proxy that handles external traffic

### 4.2 The Domain System (traefik.me)

**Traefik.me** is a clever DNS service:
- Takes any subdomain like `magic8ball.1.2.3.4.traefik.me`
- Automatically resolves it to IP `1.2.3.4`
- **No DNS configuration needed!**

### 4.3 The Request Flow

When a user visits `https://magic8ball.1.2.3.4.traefik.me`:

```
User Browser → Traefik (port 443) → Your App (port 3000) → Response
```

1. **Traefik** receives the HTTPS request
2. **Checks labels** in docker-compose.yml to route the request
3. **Routes request** to your app container on port 3000
4. **Handles SSL** automatically via Let's Encrypt

## The Complete Flow: How User Data Connects to Deployments

Here's the step-by-step connection you asked about:

```
1. terraform apply → runs user_data.sh on EC2 boot
   ↓
2. user_data.sh creates /opt/magic8ball/ directory
   ↓
3. user_data.sh creates initial docker-compose.prod.yml
   ↓
4. user_data.sh creates systemd service
   ↓
5. user_data.sh starts initial app version
   ↓
6. Developer pushes code changes to main branch
   ↓
7. GitHub Actions builds new image → pushes to registry
   ↓
8. Deploy job uses AWS SSM to execute commands on EC2
   ↓
9. Deployment script updates /opt/magic8ball/docker-compose.prod.yml
   ↓
10. Script pulls new image from GitHub Container Registry
    ↓
11. Script restarts services with updated image
    ↓
12. Users see updated app at magic8ball.IP.traefik.me
```

## Key Components Explained

### AWS Systems Manager (SSM)
- **Purpose**: Secure remote command execution
- **Why**: No SSH keys needed, AWS manages authentication
- **How**: IAM roles allow GitHub Actions to send commands to EC2

### Docker Compose Production File
- **Location**: `/opt/magic8ball/docker-compose.prod.yml`
- **Created by**: user_data.sh (initial) and updated by deployments
- **Contains**: App service + Traefik reverse proxy configuration

### Traefik Labels
These Docker labels tell Traefik how to route requests:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.magic8ball.rule=Host(`magic8ball.1.2.3.4.traefik.me`)"
  - "traefik.http.routers.magic8ball.entrypoints=websecure"
  - "traefik.http.services.magic8ball.loadbalancer.server.port=3000"
```

### GitHub Container Registry
- **URL**: `ghcr.io/username/repository-name`
- **Authentication**: GitHub token for pushes, public access for pulls
- **Versioning**: Tagged with branch names and `latest`

## Troubleshooting Common Issues

### Pipeline Failures
- **Check**: GitHub secrets are correctly set
- **Verify**: AWS permissions for the IAM user
- **Review**: Build logs in GitHub Actions tab

### Database Connection Issues
- **Ensure**: RDS instance is in running state
- **Check**: Security group allows connections from EC2
- **Verify**: Database credentials in user_data.sh

### SSL/Domain Issues
- **Wait**: DNS propagation can take time
- **Check**: Let's Encrypt rate limits
- **Verify**: Traefik.me domain format is correct

### Deployment Failures
- **SSH into EC2**: `ssh -i ~/.ssh/key ec2-user@IP`
- **Check logs**: `sudo docker-compose -f /opt/magic8ball/docker-compose.prod.yml logs`
- **Verify service**: `sudo systemctl status magic8ball.service`

## Key Insights for Junior Developers

1. **User Data is the Bridge**: Sets up initial environment for future deployments
2. **SSM is Remote Control**: Secure command execution without SSH
3. **Docker Compose is the Orchestra**: Manages multiple services as one unit
4. **Traefik.me is DNS Magic**: Eliminates DNS configuration complexity
5. **GHCR is the Artifact Store**: Built images live here between builds/deployments

## Summary

The magic happens in the connection between these components:

- **Terraform** provisions infrastructure and runs user_data.sh once
- **User data** creates the deployment target environment
- **GitHub Actions** builds and pushes new images
- **AWS SSM** provides secure remote deployment mechanism
- **Docker Compose** orchestrates the running application
- **Traefik** makes the app accessible to users

After the initial setup, deployments are simply: update image → restart services. The infrastructure stays constant while your application evolves!

---

*This walkthrough is designed to help junior developers understand not just what happens, but why each component exists and how they work together to create a complete CI/CD pipeline.*

