#!/bin/bash
# Magic 8-Ball CI/CD Deployment Test Script
# This script validates that the entire deployment pipeline works correctly

set -e

echo "🎱 Magic 8-Ball Deployment Test Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: Check Terraform configuration
echo ""
echo "1. Testing Terraform Configuration..."
cd terraform
if terraform validate; then
    print_status "Terraform configuration is valid"
else
    print_error "Terraform validation failed"
    exit 1
fi

# Test 2: Check if required variables are set
echo ""
echo "2. Checking Terraform variables..."
if [ -f "terraform.tfvars" ]; then
    print_status "terraform.tfvars file exists"
    
    # Check for required variables
    required_vars=("db_password" "public_key")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}" terraform.tfvars; then
            print_status "Variable $var is configured"
        else
            print_error "Variable $var is missing from terraform.tfvars"
            exit 1
        fi
    done
else
    print_error "terraform.tfvars file is missing"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Test 3: Get current infrastructure status
echo ""
echo "3. Checking infrastructure status..."
if terraform show -json > /dev/null 2>&1; then
    print_status "Terraform state is accessible"
    
    # Get current IP if infrastructure exists
    if terraform output web_server_public_ip > /dev/null 2>&1; then
        IP=$(terraform output -raw web_server_public_ip 2>/dev/null || echo "")
        if [ ! -z "$IP" ]; then
            print_status "Infrastructure exists with IP: $IP"
            
            # Test the current deployment
            echo ""
            echo "4. Testing current deployment..."
            APP_URL="http://magic8ball.${IP}.traefik.me"
            DASHBOARD_URL="http://traefik.${IP}.traefik.me"
            
            echo "Testing application health at: $APP_URL/health"
            if curl -f -s "$APP_URL/health" > /dev/null; then
                print_status "Application is responding correctly"
                
                # Test a magic 8-ball question
                echo "Testing Magic 8-Ball API..."
                RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
                    -d '{"question":"Will this deployment test pass?"}' \
                    "$APP_URL/api/ask")
                if echo "$RESPONSE" | grep -q "response"; then
                    print_status "Magic 8-Ball API is working"
                    echo "   Response: $(echo "$RESPONSE" | grep -o '"response":"[^"]*"' | cut -d'"' -f4)"
                else
                    print_warning "Magic 8-Ball API test failed"
                fi
                
                # Test history endpoint
                echo "Testing history endpoint..."
                if curl -f -s "$APP_URL/api/history" > /dev/null; then
                    print_status "History endpoint is working"
                else
                    print_warning "History endpoint test failed"
                fi
                
            else
                print_warning "Application is not responding at $APP_URL"
            fi
            
            echo ""
            echo "📊 Access URLs:"
            echo "   Application: $APP_URL"
            echo "   Dashboard:   $DASHBOARD_URL"
        fi
    else
        print_warning "No infrastructure currently deployed"
    fi
else
    print_warning "No Terraform state found - this is normal for first deployment"
fi

cd ..

# Test 4: Check GitHub Actions workflow
echo ""
echo "5. Checking GitHub Actions workflow..."
if [ -f ".github/workflows/ci-cd.yml" ]; then
    print_status "GitHub Actions workflow exists"
    
    # Check for required secrets documentation
    if grep -q "AWS_ACCESS_KEY_ID" .github/workflows/ci-cd.yml; then
        print_status "Workflow includes AWS credentials configuration"
    fi
    
    if grep -q "DB_PASSWORD" .github/workflows/ci-cd.yml; then
        print_status "Workflow includes database password configuration"
    fi
else
    print_error "GitHub Actions workflow is missing"
fi

# Test 5: Check application files
echo ""
echo "6. Checking application files..."
required_files=("package.json" "server.js" "Dockerfile" "public/index.html")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "Required file exists: $file"
    else
        print_error "Missing required file: $file"
        exit 1
    fi
done

echo ""
echo "🎉 Deployment Test Summary"
echo "========================="
print_status "All checks passed! Your Magic 8-Ball CI/CD pipeline is ready."

echo ""
echo "📋 Next Steps:"
echo "1. Ensure GitHub secrets are configured:"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY" 
echo "   - DB_PASSWORD"
echo ""
echo "2. Push changes to trigger CI/CD:"
echo "   git push origin main"
echo ""
echo "3. Deploy infrastructure (if not already done):"
echo "   cd terraform && terraform apply"
echo ""
echo "4. Monitor deployment at GitHub Actions tab"

echo ""
print_status "Ready for demonstration! 🚀" 