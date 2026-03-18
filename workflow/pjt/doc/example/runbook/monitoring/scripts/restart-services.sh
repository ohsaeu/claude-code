#!/bin/bash

# Service restart script for emergency situations
# Usage: ./restart-services.sh [service_name|all]

SERVICES=("nginx" "postgresql" "app" "redis")
LOG_FILE="/var/log/service-restart.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

restart_service() {
    local service=$1
    log_message "Attempting to restart $service"
    
    systemctl stop "$service"
    sleep 5
    systemctl start "$service"
    
    if systemctl is-active --quiet "$service"; then
        log_message "SUCCESS: $service restarted successfully"
        return 0
    else
        log_message "ERROR: Failed to restart $service"
        systemctl status "$service" | tee -a "$LOG_FILE"
        return 1
    fi
}

check_dependencies() {
    local service=$1
    case $service in
        "app")
            if ! systemctl is-active --quiet postgresql; then
                log_message "WARNING: PostgreSQL is not running, starting it first"
                restart_service "postgresql"
            fi
            ;;
        "nginx")
            if ! systemctl is-active --quiet app; then
                log_message "WARNING: App service is not running, starting it first"
                restart_service "app"
            fi
            ;;
    esac
}

main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
    
    if [ "$1" == "all" ] || [ -z "$1" ]; then
        log_message "Starting restart sequence for all services"
        for service in "${SERVICES[@]}"; do
            check_dependencies "$service"
            restart_service "$service"
            sleep 10
        done
    else
        check_dependencies "$1"
        restart_service "$1"
    fi
}

main "$1"