#!/bin/bash

# Deployment script for multiple environments
# Usage: ./deploy.sh [development|staging|production]

set -e

ENVIRONMENT=${1:-development}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups"
LOG_FILE="./deployment/logs/deploy_${ENVIRONMENT}_${TIMESTAMP}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Validate environment
case $ENVIRONMENT in
    development|staging|production)
        log "Deploying to $ENVIRONMENT environment"
        ;;
    *)
        error "Invalid environment: $ENVIRONMENT. Use: development, staging, or production"
        ;;
esac

# Create necessary directories
mkdir -p "$BACKUP_DIR" ./deployment/logs

# Load environment-specific configuration
ENV_FILE="./deployment/config/.env.$ENVIRONMENT"
if [[ ! -f "$ENV_FILE" ]]; then
    error "Environment file not found: $ENV_FILE"
fi

# Source environment variables
source "$ENV_FILE"

log "Starting deployment to $ENVIRONMENT environment"

# Pre-deployment checks
log "Running pre-deployment checks..."

# Check if required environment variables are set
required_vars=("NODE_ENV" "PORT" "DATABASE_URL" "REDIS_URL")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        error "Required environment variable $var is not set"
    fi
done

# Check Node.js and npm versions
node_version=$(node --version)
npm_version=$(npm --version)
log "Node.js version: $node_version"
log "npm version: $npm_version"

# Install dependencies and run tests
log "Installing dependencies..."
npm ci --production=false

log "Running linting..."
npm run lint

log "Running tests..."
npm test

log "Running security audit..."
npm audit --audit-level high

# Database backup (production only)
if [[ "$ENVIRONMENT" == "production" ]]; then
    log "Creating database backup..."
    ./deployment/scripts/backup-db.sh "$BACKUP_DIR/db_backup_${TIMESTAMP}.sql"
fi

# Build application
log "Building application..."
npm run build

# Environment-specific deployment
case $ENVIRONMENT in
    development)
        log "Deploying to development..."
        # For development, we might just restart the local service
        pm2 reload ecosystem.config.js --env development || pm2 start ecosystem.config.js --env development
        ;;
    staging)
        log "Deploying to staging..."
        # Docker deployment for staging
        docker build -f deployment/docker/Dockerfile.prod -t runbook-api:staging .
        docker stop runbook-staging || true
        docker rm runbook-staging || true
        docker run -d --name runbook-staging -p 3001:3000 --env-file "$ENV_FILE" runbook-api:staging
        ;;
    production)
        log "Deploying to production..."
        # Kubernetes deployment for production
        kubectl apply -f deployment/k8s/prod/
        kubectl rollout status deployment/runbook-api -n production --timeout=300s
        ;;
esac

# Health check
log "Performing health check..."
sleep 30  # Wait for service to start
./deployment/scripts/health-check.sh "$ENVIRONMENT"

# Smoke tests
log "Running smoke tests..."
./deployment/scripts/smoke-test.sh "$ENVIRONMENT"

# Cleanup old deployments (keep last 5)
log "Cleaning up old deployments..."
if [[ "$ENVIRONMENT" == "production" ]]; then
    # Keep only last 5 backups
    ls -t "$BACKUP_DIR"/db_backup_*.sql | tail -n +6 | xargs -r rm
    
    # Clean up old Docker images
    docker image prune -f
fi

# Update deployment record
echo "{
    \"timestamp\": \"$TIMESTAMP\",
    \"environment\": \"$ENVIRONMENT\",
    \"version\": \"$(git rev-parse HEAD)\",
    \"deployed_by\": \"$(whoami)\",
    \"status\": \"success\"
}" > "./deployment/logs/last_deployment_${ENVIRONMENT}.json"

success "Deployment to $ENVIRONMENT completed successfully!"
log "Deployment log: $LOG_FILE"

# Send notification (if configured)
if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"✅ Deployment to $ENVIRONMENT completed successfully!\"}" \
        "$SLACK_WEBHOOK_URL"
fi