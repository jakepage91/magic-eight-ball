# 🎱 Magic Eight Ball - Complete CI/CD Demonstration

A comprehensive demonstration application showcasing the full software development lifecycle from code to production deployment. This project is designed for teaching CI/CD concepts and includes everything needed to understand modern DevOps practices.

## 🚀 What This Project Demonstrates

- **Frontend Development**: Modern HTML/CSS/JavaScript with beautiful UI
- **Backend Development**: Node.js/Express REST API
- **Database Integration**: PostgreSQL with connection pooling
- **Containerization**: Docker multi-stage builds
- **CI/CD Pipeline**: GitHub Actions with automated testing and deployment
- **Infrastructure as Code**: Terraform for AWS resources
- **Public DNS**: Automatic SSL certificates via Traefik and traefik.me
- **Security Best Practices**: Non-root containers, encrypted storage, IAM roles

## 🏗️ Architecture

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

## 📦 Components

### Frontend
- **Technology**: Vanilla HTML, CSS, JavaScript
- **Features**: Interactive magic 8-ball animation, question history, responsive design
- **UI/UX**: Modern gradient design with shake animations

### Backend
- **Technology**: Node.js, Express.js
- **Features**: RESTful API, database integration, health checks
- **Security**: Helmet.js for security headers, CORS configuration

### Database
- **Technology**: PostgreSQL 15
- **Features**: Question/response logging, indexes for performance
- **Security**: VPC isolation, encrypted storage

### Infrastructure
- **AWS Services**: EC2, RDS, VPC, Security Groups, IAM
- **Networking**: Public/private subnets, internet gateway
- **Security**: Encrypted EBS volumes, security groups, IAM roles

## 🛠️ Local Development

### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- Git

### Quick Start
```bash
# Clone the repository
git clone https://github.com/your-username/magic-eight-ball.git
cd magic-eight-ball

# Install dependencies
npm install

# Start with Docker Compose (includes database)
docker-compose up -d

# Access the application
open http://localhost:3000
```

### Manual Setup
```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your database settings

# Start PostgreSQL (if not using Docker)
# Create database 'magic_eight_ball'

# Run the application
npm run dev
```

## 🚀 Deployment Setup

### 1. Fork & Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/magic-eight-ball.git
cd magic-eight-ball
```

### 2. AWS Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured
- Generate an SSH key pair for EC2 access

### 3. Configure GitHub Secrets
Add these secrets to your GitHub repository settings:

```
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
DB_PASSWORD=your_secure_database_password
```

### 4. Deploy Infrastructure with Terraform
```bash
cd terraform

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

### 5. Trigger CI/CD Pipeline
```bash
# Make any change and push to main branch
git add .
git commit -m "Deploy magic eight ball"
git push origin main
```

## 🔄 CI/CD Pipeline Stages

### 1. **Test Stage**
- Runs on every push and PR
- Installs dependencies with `npm ci`
- Executes Jest test suite
- Runs linting (if configured)

### 2. **Build & Push Stage** 
- Triggered on push to main/develop
- Builds multi-architecture Docker image (amd64/arm64)
- Pushes to GitHub Container Registry
- Uses build caching for efficiency

### 3. **Deploy Stage**
- Triggered on push to main branch only
- Uses AWS SSM to deploy to EC2 instance
- Updates running containers with zero downtime
- Configures Traefik for SSL termination

## 🌐 Access Points

After successful deployment, access your application at:

- **Application**: https://magic8ball.traefik.me
- **Traefik Dashboard**: https://traefik.traefik.me
- **Direct IP**: http://YOUR_EC2_PUBLIC_IP

## 🧪 Testing

### Run Tests Locally
```bash
# Run all tests
npm test

# Run tests with coverage
npm test -- --coverage

# Run tests in watch mode
npm test -- --watch
```

### API Endpoints for Testing
```bash
# Health check
curl http://localhost:3000/health

# Ask a question
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Will this demo work?"}'

# Get question history
curl http://localhost:3000/api/history
```

## 🔧 Configuration

### Environment Variables
- `NODE_ENV`: Runtime environment (development/production)
- `PORT`: Server port (default: 3000)
- `DATABASE_URL`: PostgreSQL connection string

### Terraform Variables
- `aws_region`: AWS region for deployment
- `project_name`: Name prefix for all resources
- `environment`: Environment tag (development/staging/production)
- `instance_type`: EC2 instance size
- `db_instance_class`: RDS instance size
- `allowed_ssh_cidrs`: IP ranges allowed for SSH access

## 📚 Teaching Points for CI/CD Class

### 1. **Version Control**
- Git branching strategies
- Semantic commit messages
- Pull request workflow

### 2. **Containerization**
- Multi-stage Docker builds
- Image optimization techniques
- Container security best practices

### 3. **CI/CD Pipeline**
- Automated testing strategies
- Build artifact management
- Deployment automation
- Environment promotion

### 4. **Infrastructure as Code**
- Terraform state management
- Resource tagging strategies
- Security group configuration
- VPC design patterns

### 5. **Monitoring & Observability**
- Health check endpoints
- Log aggregation
- Application metrics
- Infrastructure monitoring

### 6. **Security**
- Secret management
- Container security
- Network security
- IAM best practices

## 🐛 Troubleshooting

### Common Issues

**Pipeline Failures:**
- Check GitHub secrets are correctly set
- Verify AWS permissions
- Review build logs in Actions tab

**Database Connection:**
- Ensure RDS is in running state
- Check security group rules
- Verify database credentials

**Traefik SSL Issues:**
- DNS propagation can take time
- Check Let's Encrypt rate limits
- Verify domain configuration

**SSH Access:**
- Ensure your public key is in terraform.tfvars
- Check security group SSH rules
- Verify key pair was created

### Debug Commands
```bash
# Check container logs
docker-compose logs -f app

# Connect to EC2 instance
ssh -i ~/.ssh/magic8ball-key ec2-user@YOUR_EC2_IP

# Check service status on EC2
sudo systemctl status magic8ball.service
sudo docker-compose -f /opt/magic8ball/docker-compose.prod.yml logs
```

## 🧹 Cleanup

### Destroy Infrastructure
```bash
cd terraform
terraform destroy
```

### Stop Local Services
```bash
docker-compose down -v
```

## 📖 Learning Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## 🤝 Contributing

This is a demonstration project for educational purposes. Feel free to fork and modify for your own learning!

## 📄 License

MIT License - see LICENSE file for details.

---

**Happy Learning! 🎓**

This project demonstrates real-world DevOps practices in a simplified, educational context. Each component is designed to teach specific concepts while working together as a complete system. 

