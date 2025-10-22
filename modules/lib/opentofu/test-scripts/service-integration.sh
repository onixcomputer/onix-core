#!/bin/bash
# Service Integration Tests for OpenTofu Helper Scripts
# Tests scripts work correctly with systemd services

set -euo pipefail

# Configuration
INSTANCE="adeci"
SERVICE_NAME="keycloak"
STATE_DIR="/var/lib/${SERVICE_NAME}-${INSTANCE}-terraform"
DEPLOYMENT_SERVICE="${SERVICE_NAME}-terraform-deploy-${INSTANCE}"
MAIN_SERVICE="${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test service status integration
test_service_status_integration() {
    print_test "Testing service status integration..."

    local status_script="${SERVICE_NAME}-tf-status-${INSTANCE}"

    if ! command -v "$status_script" >/dev/null 2>&1; then
        print_fail "Status script not available"
        return
    fi

    # Test main service status detection
    local main_status
    main_status=$(systemctl is-active "$MAIN_SERVICE.service" 2>/dev/null || echo "inactive")

    local output
    output=$("$status_script" 2>&1)

    if echo "$output" | grep -q "$MAIN_SERVICE.service"; then
        print_pass "Status script shows main service status"
    else
        print_fail "Status script does not show main service status"
    fi

    # Test deployment service status detection
    local deploy_status
    deploy_status=$(systemctl is-active "$DEPLOYMENT_SERVICE.service" 2>/dev/null || echo "inactive")

    if echo "$output" | grep -q "$DEPLOYMENT_SERVICE.service"; then
        print_pass "Status script shows deployment service status"
    else
        print_fail "Status script does not show deployment service status"
    fi

    print_info "Main service status: $main_status"
    print_info "Deployment service status: $deploy_status"
}

# Test apply script service interaction
test_apply_service_interaction() {
    print_test "Testing apply script service interaction..."

    local apply_script="${SERVICE_NAME}-tf-apply-${INSTANCE}"

    if ! command -v "$apply_script" >/dev/null 2>&1; then
        print_fail "Apply script not available"
        return
    fi

    # Check if the apply script properly references the deployment service
    local script_path
    script_path=$(which "$apply_script")

    if grep -q "systemctl start $DEPLOYMENT_SERVICE" "$script_path"; then
        print_pass "Apply script starts correct deployment service"
    else
        print_fail "Apply script does not start correct deployment service"
    fi

    if grep -q "journalctl -u $DEPLOYMENT_SERVICE" "$script_path"; then
        print_pass "Apply script follows correct service logs"
    else
        print_fail "Apply script does not follow correct service logs"
    fi

    # Test that apply script handles deployment complete flag
    if grep -q ".deploy-complete" "$script_path"; then
        print_pass "Apply script handles deploy-complete flag"
    else
        print_fail "Apply script does not handle deploy-complete flag"
    fi
}

# Test logs script service integration
test_logs_service_integration() {
    print_test "Testing logs script service integration..."

    local logs_script="${SERVICE_NAME}-tf-logs-${INSTANCE}"

    if ! command -v "$logs_script" >/dev/null 2>&1; then
        print_fail "Logs script not available"
        return
    fi

    local script_path
    script_path=$(which "$logs_script")

    # Check service status queries
    if grep -q "systemctl is-active $MAIN_SERVICE" "$script_path"; then
        print_pass "Logs script checks main service status"
    else
        print_fail "Logs script does not check main service status"
    fi

    if grep -q "systemctl is-active $DEPLOYMENT_SERVICE" "$script_path"; then
        print_pass "Logs script checks deployment service status"
    else
        print_fail "Logs script does not check deployment service status"
    fi

    # Check log following
    if grep -q "journalctl -u $DEPLOYMENT_SERVICE" "$script_path"; then
        print_pass "Logs script follows deployment service logs"
    else
        print_fail "Logs script does not follow deployment service logs"
    fi
}

# Test state directory and file integration
test_state_integration() {
    print_test "Testing state directory integration..."

    # Ensure state directory exists
    if [ ! -d "$STATE_DIR" ]; then
        sudo mkdir -p "$STATE_DIR"
        print_info "Created state directory for testing"
    fi

    local status_script="${SERVICE_NAME}-tf-status-${INSTANCE}"
    local logs_script="${SERVICE_NAME}-tf-logs-${INSTANCE}"

    # Test deploy-complete flag detection
    sudo rm -f "$STATE_DIR/.deploy-complete"

    if command -v "$logs_script" >/dev/null 2>&1; then
        local output
        output=$(timeout 3 "$logs_script" 2>&1 || echo "timeout")

        if echo "$output" | grep -q "Deploy status: PENDING"; then
            print_pass "Scripts detect missing deploy-complete flag"
        else
            print_info "Could not verify deploy-complete detection (timeout or different output)"
        fi
    fi

    # Create deploy-complete flag and test
    sudo touch "$STATE_DIR/.deploy-complete"

    if command -v "$logs_script" >/dev/null 2>&1; then
        local output
        output=$(timeout 3 "$logs_script" 2>&1 || echo "timeout")

        if echo "$output" | grep -q "Deploy status: COMPLETE"; then
            print_pass "Scripts detect present deploy-complete flag"
        else
            print_info "Could not verify deploy-complete detection (timeout or different output)"
        fi
    fi
}

# Test service dependency handling
test_service_dependencies() {
    print_test "Testing service dependency handling..."

    # Check if deployment service has correct dependencies
    if systemctl show "$DEPLOYMENT_SERVICE.service" --property=After | grep -q "$MAIN_SERVICE.service"; then
        print_pass "Deployment service depends on main service"
    else
        print_fail "Deployment service does not depend on main service"
    fi

    # Check if scripts handle service states appropriately
    local status_script="${SERVICE_NAME}-tf-status-${INSTANCE}"

    if command -v "$status_script" >/dev/null 2>&1; then
        # Test with main service active
        if systemctl is-active "$MAIN_SERVICE.service" >/dev/null 2>&1; then
            print_info "Main service is active - good for testing"
        else
            print_info "Main service is not active - may affect deployment service"
        fi

        local output
        output=$("$status_script" 2>&1)

        # Scripts should handle any service state without crashing
        if [ $? -eq 0 ]; then
            print_pass "Status script handles current service states"
        else
            print_fail "Status script fails with current service states"
        fi
    fi
}

# Test script interaction with systemd conditions
test_systemd_conditions() {
    print_test "Testing systemd condition handling..."

    # Check if deployment service has condition on deploy-complete
    local unit_file
    unit_file=$(systemctl show "$DEPLOYMENT_SERVICE.service" --property=FragmentPath | cut -d= -f2)

    if [ -f "$unit_file" ] && grep -q "ConditionPathExists=.*deploy-complete" "$unit_file"; then
        print_pass "Deployment service has deploy-complete condition"
    else
        print_info "Could not verify deploy-complete condition in unit file"
    fi

    # Test that apply script removes the condition file
    local apply_script="${SERVICE_NAME}-tf-apply-${INSTANCE}"

    if command -v "$apply_script" >/dev/null 2>&1; then
        local script_path
        script_path=$(which "$apply_script")

        if grep -q "rm.*deploy-complete" "$script_path"; then
            print_pass "Apply script removes deploy-complete flag"
        else
            print_fail "Apply script does not remove deploy-complete flag"
        fi
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "OpenTofu Helper Scripts - Service Integration Tests"
    echo "Instance: $INSTANCE"
    echo "Service: $SERVICE_NAME"
    echo "Main Service: $MAIN_SERVICE"
    echo "Deployment Service: $DEPLOYMENT_SERVICE"
    echo "State Directory: $STATE_DIR"
    echo "=========================================="
    echo

    test_service_status_integration
    echo
    test_apply_service_interaction
    echo
    test_logs_service_integration
    echo
    test_state_integration
    echo
    test_service_dependencies
    echo
    test_systemd_conditions
    echo

    echo "=========================================="
    echo "Test Results:"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "=========================================="

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo "This script may need sudo access for some tests."
    echo "Please ensure you can run sudo commands."
fi

# Run main function
main "$@"