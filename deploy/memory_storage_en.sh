#!/bin/bash

# ACME In-Memory Storage Deployment Script
# For acme.sh HTTP-01 validation
# 
# Parameters:
#   $1: Domain
#   $2: Challenge token
#   $3: Challenge response content

set -e

# Configuration
SERVER_URL="${ACME_SERVER_URL:-http://localhost:80}"
CHALLENGE_PATH="/.well-known/acme-challenge"
LOG_FILE="${ACME_LOG_FILE:-/tmp/acme-memory-storage.log}"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Get parameters
domain="$1"
token="$2"
response="$3"

# Validate parameters
if [ -z "$domain" ]; then
    log_error "Domain parameter missing"
    exit 1
fi

if [ -z "$token" ]; then
    log_error "Challenge token parameter missing"
    exit 1
fi

if [ -z "$response" ]; then
    log_error "Challenge response parameter missing"
    exit 1
fi

# Record start time
start_time=$(date +%s)
log_info "Starting ACME challenge processing: domain=$domain, token=$token"

# Check if service is available
check_service() {
    if ! curl -s -f "${SERVER_URL}${CHALLENGE_PATH}/health" > /dev/null; then
        log_error "ACME challenge service unavailable: ${SERVER_URL}"
        return 1
    fi
    return 0
}

# Add challenge response to memory
add_challenge_response() {
    local retry_count=0
    local max_retries=3
    local retry_delay=2
    
    while [ $retry_count -lt $max_retries ]; do
        log_info "Attempting to add challenge response (attempt $((retry_count + 1))/$max_retries)"
        
        # Send POST request to add challenge response
        http_response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: text/plain" \
            -d "$response" \
            "${SERVER_URL}${CHALLENGE_PATH}/${token}")
        
        # Separate response body and status code
        http_body=$(echo "$http_response" | head -n -1)
        http_status=$(echo "$http_response" | tail -n 1)
        
        if [ "$http_status" = "200" ]; then
            log_success "Challenge response added successfully"
            return 0
        else
            log_warning "Failed to add challenge response, status code: $http_status, response: $http_body"
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                log_info "Waiting ${retry_delay} seconds before retry..."
                sleep $retry_delay
                retry_delay=$((retry_delay * 2))
            fi
        fi
    done
    
    log_error "Failed to add challenge response, reached maximum retry attempts"
    return 1
}

# Verify challenge response has been added
verify_challenge_response() {
    local retry_count=0
    local max_retries=5
    local retry_delay=1
    
    log_info "Verifying challenge response has been added correctly..."
    
    while [ $retry_count -lt $max_retries ]; do
        # Get challenge response
        actual_response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/${token}")
        
        if [ "$actual_response" = "$response" ]; then
            log_success "Challenge response verification successful"
            return 0
        else
            log_warning "Challenge response verification failed (attempt $((retry_count + 1))/$max_retries)"
            log_warning "Expected: $response"
            log_warning "Actual: $actual_response"
            
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                log_info "Waiting ${retry_delay} seconds before retry verification..."
                sleep $retry_delay
            fi
        fi
    done
    
    log_error "Challenge response verification failed, reached maximum retry attempts"
    return 1
}

# Get challenge response statistics
get_challenge_stats() {
    log_info "Getting challenge response statistics..."
    
    stats_response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/debug/stats")
    
    if [ $? -eq 0 ]; then
        log_info "Statistics: $stats_response"
    else
        log_warning "Unable to get statistics"
    fi
}

# Main execution flow
main() {
    # Check service availability
    if ! check_service; then
        exit 1
    fi
    
    # Add challenge response
    if ! add_challenge_response; then
        exit 1
    fi
    
    # Verify challenge response
    if ! verify_challenge_response; then
        # If verification fails, try to delete and re-add
        log_warning "Verification failed, attempting to re-add challenge response..."
        curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/${token}" > /dev/null
        
        if ! add_challenge_response; then
            exit 1
        fi
        
        if ! verify_challenge_response; then
            exit 1
        fi
    fi
    
    # Get statistics
    get_challenge_stats
    
    # Calculate execution time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log_success "ACME challenge processing completed, duration: ${duration} seconds"
    log_info "Challenge response added to memory storage: domain=$domain, token=$token"
    
    # Output success message to acme.sh
    echo "Challenge response added to memory storage for domain: $domain, token: $token"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "Script execution failed, exit code: $exit_code"
        
        # Try to clean up partially added challenge response
        log_info "Attempting to clean up challenge response..."
        curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/${token}" > /dev/null
    fi
    
    exit $exit_code
}

# Set signal handler
trap cleanup EXIT

# Execute main flow
main "$@" 