#!/bin/bash

# ACME In-Memory Challenge Controller Test Script
# Test Spring Boot application's HTTP-01 challenge validation functionality

set -e

# Configuration
SERVER_URL="http://localhost:80"
CHALLENGE_PATH="/.well-known/acme-challenge"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if service is running
check_service() {
    log_info "Checking ACME challenge service status..."
    
    if curl -s -f "${SERVER_URL}${CHALLENGE_PATH}/health" > /dev/null; then
        log_success "Service is running normally"
        return 0
    else
        log_error "Service is not running or cannot be accessed"
        return 1
    fi
}

# Get service health status
get_health_status() {
    log_info "Getting service health status..."
    
    response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/health")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# Add challenge response
add_challenge() {
    local token="$1"
    local response="$2"
    
    log_info "Adding challenge response: token=$token"
    
    curl -s -X POST \
        -H "Content-Type: text/plain" \
        -d "$response" \
        "${SERVER_URL}${CHALLENGE_PATH}/${token}"
    
    echo
}

# Verify challenge response
verify_challenge() {
    local token="$1"
    local expected_response="$2"
    
    log_info "Verifying challenge response: token=$token"
    
    actual_response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/${token}")
    
    if [ "$actual_response" = "$expected_response" ]; then
        log_success "Challenge verification successful"
        echo "Expected: $expected_response"
        echo "Actual: $actual_response"
    else
        log_error "Challenge verification failed"
        echo "Expected: $expected_response"
        echo "Actual: $actual_response"
        return 1
    fi
}

# Batch add challenge responses
add_batch_challenges() {
    log_info "Adding batch challenge responses..."
    
    # Create test data
    cat > /tmp/challenges.json << EOF
{
    "test-token-1": "test-token-1.test-response-1",
    "test-token-2": "test-token-2.test-response-2",
    "test-token-3": "test-token-3.test-response-3"
}
EOF
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/challenges.json \
        "${SERVER_URL}${CHALLENGE_PATH}/batch"
    
    echo
}

# Get statistics
get_stats() {
    log_info "Getting challenge response statistics..."
    
    response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/debug/stats")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# Get all challenge responses
get_all_challenges() {
    log_info "Getting all challenge responses..."
    
    response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/debug/all")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# Delete challenge response
delete_challenge() {
    local token="$1"
    
    log_info "Deleting challenge response: token=$token"
    
    curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/${token}"
    echo
}

# Clear all challenge responses
clear_all_challenges() {
    log_info "Clearing all challenge responses..."
    
    curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/clear"
    echo
}

# Simulate real ACME challenge flow
simulate_acme_flow() {
    log_info "Simulating real ACME challenge flow..."
    
    # 1. Generate test token and response
    local token="acme-challenge-$(date +%s)"
    local response="${token}.test-response-$(date +%s)"
    
    log_info "Generated test data:"
    echo "  Token: $token"
    echo "  Response: $response"
    
    # 2. Add challenge response
    add_challenge "$token" "$response"
    
    # 3. Verify challenge response
    verify_challenge "$token" "$response"
    
    # 4. Wait for a while (simulate validation process)
    log_info "Waiting 2 seconds to simulate validation process..."
    sleep 2
    
    # 5. Verify again (ensure response is still available)
    verify_challenge "$token" "$response"
    
    # 6. Delete challenge response (simulate cleanup after validation)
    delete_challenge "$token"
    
    log_success "ACME challenge flow simulation completed"
}

# Main test flow
main() {
    echo "=========================================="
    echo "ACME In-Memory Challenge Controller Test"
    echo "=========================================="
    
    # Check service status
    if ! check_service; then
        log_error "Please start the Spring Boot application first"
        exit 1
    fi
    
    echo
    
    # Get health status
    get_health_status
    echo
    
    # Clear existing challenge responses
    clear_all_challenges
    echo
    
    # Test single challenge response
    log_info "=== Testing Single Challenge Response ==="
    add_challenge "test-token-001" "test-token-001.test-response-001"
    verify_challenge "test-token-001" "test-token-001.test-response-001"
    echo
    
    # Test batch addition
    log_info "=== Testing Batch Challenge Response Addition ==="
    add_batch_challenges
    echo
    
    # Verify batch addition results
    verify_challenge "test-token-1" "test-token-1.test-response-1"
    verify_challenge "test-token-2" "test-token-2.test-response-2"
    verify_challenge "test-token-3" "test-token-3.test-response-3"
    echo
    
    # Get statistics
    log_info "=== Getting Statistics ==="
    get_stats
    echo
    
    # Get all challenge responses
    log_info "=== Getting All Challenge Responses ==="
    get_all_challenges
    echo
    
    # Simulate real ACME flow
    log_info "=== Simulating Real ACME Challenge Flow ==="
    simulate_acme_flow
    echo
    
    # Final statistics
    log_info "=== Final Statistics ==="
    get_stats
    echo
    
    log_success "All tests completed!"
}

# Help information
show_help() {
    echo "ACME In-Memory Challenge Controller Test Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help      Show this help information"
    echo "  --health        Check service health status"
    echo "  --stats         Get statistics"
    echo "  --all           Get all challenge responses"
    echo "  --clear         Clear all challenge responses"
    echo "  --simulate      Simulate ACME challenge flow"
    echo
    echo "Examples:"
    echo "  $0              Run complete test"
    echo "  $0 --health     Check service status"
    echo "  $0 --simulate   Simulate challenge flow"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --health)
        check_service && get_health_status
        exit 0
        ;;
    --stats)
        check_service && get_stats
        exit 0
        ;;
    --all)
        check_service && get_all_challenges
        exit 0
        ;;
    --clear)
        check_service && clear_all_challenges
        exit 0
        ;;
    --simulate)
        check_service && simulate_acme_flow
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 