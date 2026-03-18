#!/bin/bash

# Rollback script for multiple environments
# Usage: ./rollback.sh [development|staging|production] [version_or_backup]

set -e

ENVIRONMENT=${1:-development}
VERSION=${2}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="./deployment/logs/rollback_${ENVIRONMENT}_${TIMESTAMP}.log"

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
        log "Rolling back $ENVIRONMENT environment"
        ;;
    *)
        error "Invalid environment: $ENVIRONMENT. Use: development, staging, or production"
        ;;
esac

# Create log directory
mkdir -p ./deployment/logs

# Confirmation prompt for production
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${RED}WARNING: You are about to rollback PRODUCTION environment!${NC}"
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log "Rollback cancelled by user"
        exit 0
    fi
fi

log "Starting rollback for $ENVIRONMENT environment"

# Get available versions/backups
get_available_versions() {
    case $ENVIRONMENT in
        development)
            git tag --sort=-version:refname | head -10
            ;;
        staging)
            docker images runbook-api --format "table {{.Tag}}" | grep -v TAG | head -10
            ;;
        production)
            kubectl get deployments runbook-api -n production -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
            ;;
    esac
}

# If no version specified, show available options
if [[ -z "$VERSION" ]]; then
    log "Available versions for rollback:"
    get_available_versions
    read -p "Enter version to rollback to: " VERSION
fi

log "Rolling back to version: $VERSION"

# Pre-rollback backup (production only)
if [[ "$ENVIRONMENT" == "production" ]]; then
    log "Creating pre-rollback database backup..."
    ./deployment/scripts/backup-db.sh "./backups/pre_rollback_backup_${TIMESTAMP}.sql"
fi

# Environment-specific rollback
case $ENVIRONMENT in
    development)
        log "Rolling back development environment..."
        
        # Git rollback
        if git rev-parse --verify "$VERSION" >/dev/null 2>&1; then
            git checkout "$VERSION"
            npm ci
            pm2 reload ecosystem.config.js --env development
        else
            error "Invalid git version: $VERSION"
        fi
        ;;
        
    staging)
        log "Rolling back staging environment..."
        
        # Docker rollback
        if docker images -q "runbook-api:$VERSION" | grep -q .; then
            docker stop runbook-staging || true
            docker rm runbook-staging || true
            docker run -d --name runbook-staging -p 3001:3000 \
                --env-file "./deployment/config/.env.staging" \
                "runbook-api:$VERSION"
        else
            error "Docker image not found: runbook-api:$VERSION"
        fi
        ;;
        
    production)
        log "Rolling back production environment..."
        
        # Kubernetes rollback
        if kubectl rollout history deployment/runbook-api -n production | grep -q "$VERSION"; then
            kubectl rollout undo deployment/runbook-api -n production --to-revision="$VERSION"
            kubectl rollout status deployment/runbook-api -n production --timeout=300s
        else
            # Database rollback if needed
            if [[ -n "$3" && "$3" == "--with-db" ]]; then
                warning "Database rollback requested"
                read -p "Enter database backup file to restore: " DB_BACKUP
                if [[ -f "$DB_BACKUP" ]]; then
                    log "Restoring database from $DB_BACKUP"
                    ./deployment/scripts/restore-db.sh "$DB_BACKUP"
                else
                    error "Database backup file not found: $DB_BACKUP"
                fi
            fi
            
            error "Invalid revision number for Kubernetes: $VERSION"
        fi
        ;;
esac

# Health check after rollback
log "Performing post-rollback health check..."
sleep 30  # Wait for service to stabilize
./deployment/scripts/health-check.sh "$ENVIRONMENT"

# Run smoke tests
log "Running post-rollback smoke tests..."
./deployment/scripts/smoke-test.sh "$ENVIRONMENT"

# Update rollback record
echo "{
    \"timestamp\": \"$TIMESTAMP\",
    \"environment\": \"$ENVIRONMENT\",
    \"rolled_back_to\": \"$VERSION\",
    \"rolled_back_by\": \"$(whoami)\",
    \"status\": \"success\"
}" > "./deployment/logs/last_rollback_${ENVIRONMENT}.json"

success "Rollback to $VERSION completed successfully!"
log "Rollback log: $LOG_FILE"

# Send notification (if configured)
if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"⚠️ Rollback in $ENVIRONMENT to version $VERSION completed!\"}" \
        "$SLACK_WEBHOOK_URL"
fi

# Additional monitoring after production rollback
if [[ "$ENVIRONMENT" == "production" ]]; then
    log "Setting up enhanced monitoring for 1 hour post-rollback"
    # This could trigger additional monitoring alerts
    echo "production_rollback_monitoring=true" > ./deployment/logs/monitoring_flag
fi