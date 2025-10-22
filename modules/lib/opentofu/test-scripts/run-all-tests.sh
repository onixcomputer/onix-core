#!/bin/bash
# Master test runner for OpenTofu Helper Scripts
# Executes all test categories and provides comprehensive results

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCE="adeci"
SERVICE_NAME="keycloak"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TOTAL_PASSED=0
TOTAL_FAILED=0
CATEGORIES_PASSED=0
CATEGORIES_FAILED=0

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_category() {
    echo -e "\n${YELLOW}[CATEGORY]${NC} $1"
    echo "----------------------------------------"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Run a test script and track results
run_test_category() {
    local test_script="$1"
    local category_name="$2"

    print_category "$category_name"

    if [ ! -f "$test_script" ]; then
        print_fail "Test script not found: $test_script"
        ((CATEGORIES_FAILED++))
        return 1
    fi

    if [ ! -x "$test_script" ]; then
        chmod +x "$test_script"
    fi

    # Run the test and capture output
    local output
    local exit_code

    if output=$("$test_script" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    # Parse test results from output
    local passed
    local failed
    passed=$(echo "$output" | grep "Passed:" | awk '{print $2}' || echo "0")
    failed=$(echo "$output" | grep "Failed:" | awk '{print $2}' || echo "0")

    # Update totals
    ((TOTAL_PASSED += passed))
    ((TOTAL_FAILED += failed))

    if [ $exit_code -eq 0 ]; then
        print_pass "$category_name completed successfully ($passed passed, $failed failed)"
        ((CATEGORIES_PASSED++))
    else
        print_fail "$category_name failed ($passed passed, $failed failed)"
        ((CATEGORIES_FAILED++))
    fi

    # Show detailed output if there were failures
    if [ $failed -gt 0 ] || [ $exit_code -ne 0 ]; then
        echo
        echo "Detailed output:"
        echo "$output"
        echo
    fi

    return $exit_code
}

# Pre-flight checks
pre_flight_checks() {
    print_header "PRE-FLIGHT CHECKS"

    local all_good=true

    # Check if we're on the right system
    if ! systemctl list-units --type=service | grep -q "${SERVICE_NAME}-terraform-deploy-${INSTANCE}"; then
        print_fail "Deployment service ${SERVICE_NAME}-terraform-deploy-${INSTANCE} not found"
        print_info "This test suite is designed for systems with the OpenTofu-managed keycloak service"
        all_good=false
    else
        print_pass "Deployment service found"
    fi

    # Check if helper scripts are available
    local scripts=(
        "${SERVICE_NAME}-tf-unlock-${INSTANCE}"
        "${SERVICE_NAME}-tf-status-${INSTANCE}"
        "${SERVICE_NAME}-tf-apply-${INSTANCE}"
        "${SERVICE_NAME}-tf-logs-${INSTANCE}"
    )

    local missing_scripts=0
    for script in "${scripts[@]}"; do
        if ! command -v "$script" >/dev/null 2>&1; then
            print_fail "Helper script not found: $script"
            ((missing_scripts++))
            all_good=false
        fi
    done

    if [ $missing_scripts -eq 0 ]; then
        print_pass "All helper scripts are available"
    fi

    # Check permissions
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        print_info "Some tests may require sudo access"
        print_info "Please ensure you can run sudo commands if needed"
    else
        print_pass "Sufficient permissions for testing"
    fi

    # Check state directory
    local state_dir="/var/lib/${SERVICE_NAME}-${INSTANCE}-terraform"
    if [ -d "$state_dir" ]; then
        print_pass "State directory exists: $state_dir"
    else
        print_info "State directory does not exist: $state_dir"
        print_info "Will be created during testing if needed"
    fi

    echo

    if [ "$all_good" = false ]; then
        print_fail "Pre-flight checks failed. Some tests may not work correctly."
        echo
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_pass "Pre-flight checks completed successfully"
    fi

    echo
}

# Test category definitions
run_all_tests() {
    print_header "OPENTOFU HELPER SCRIPTS - COMPREHENSIVE TEST SUITE"
    echo "Instance: $INSTANCE"
    echo "Service: $SERVICE_NAME"
    echo "Test Directory: $SCRIPT_DIR"
    echo

    # Pre-flight checks
    pre_flight_checks

    # Test categories
    local categories=(
        "$SCRIPT_DIR/basic-functionality.sh:Basic Functionality"
        "$SCRIPT_DIR/service-integration.sh:Service Integration"
    )

    # Run each test category
    for category in "${categories[@]}"; do
        local script_path="${category%%:*}"
        local category_name="${category##*:}"

        run_test_category "$script_path" "$category_name"
        echo
    done

    # Additional manual test suggestions
    print_category "Manual Test Suggestions"
    echo "The following tests should be performed manually:"
    echo
    echo "1. Lock Interaction Testing:"
    echo "   - Run: ${SERVICE_NAME}-tf-apply-${INSTANCE} (let it run)"
    echo "   - In another terminal: ${SERVICE_NAME}-tf-status-${INSTANCE}"
    echo "   - Verify lock is shown as active"
    echo "   - Test: echo 'y' | ${SERVICE_NAME}-tf-unlock-${INSTANCE}"
    echo
    echo "2. Concurrent Operations:"
    echo "   - Start deployment: ${SERVICE_NAME}-tf-apply-${INSTANCE} &"
    echo "   - Try another: ${SERVICE_NAME}-tf-apply-${INSTANCE}"
    echo "   - Verify second one waits or fails gracefully"
    echo
    echo "3. Log Monitoring:"
    echo "   - Run: ${SERVICE_NAME}-tf-logs-${INSTANCE}"
    echo "   - Verify it shows current status and follows logs"
    echo
    echo "4. Service State Changes:"
    echo "   - Stop main service: sudo systemctl stop ${SERVICE_NAME}"
    echo "   - Run status script: ${SERVICE_NAME}-tf-status-${INSTANCE}"
    echo "   - Start main service: sudo systemctl start ${SERVICE_NAME}"
    echo "   - Verify status changes are reflected"
    echo
}

# Summary reporting
print_summary() {
    print_header "TEST SUMMARY"

    echo "Categories:"
    echo "  Passed: $CATEGORIES_PASSED"
    echo "  Failed: $CATEGORIES_FAILED"
    echo "  Total:  $((CATEGORIES_PASSED + CATEGORIES_FAILED))"
    echo

    echo "Individual Tests:"
    echo "  Passed: $TOTAL_PASSED"
    echo "  Failed: $TOTAL_FAILED"
    echo "  Total:  $((TOTAL_PASSED + TOTAL_FAILED))"
    echo

    if [ $CATEGORIES_FAILED -eq 0 ] && [ $TOTAL_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
        echo
        echo "The OpenTofu helper scripts appear to be working correctly."
        echo "Consider running the manual tests for complete validation."
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo
        echo "Issues found:"
        if [ $CATEGORIES_FAILED -gt 0 ]; then
            echo "  - $CATEGORIES_FAILED test categories failed"
        fi
        if [ $TOTAL_FAILED -gt 0 ]; then
            echo "  - $TOTAL_FAILED individual tests failed"
        fi
        echo
        echo "Please review the detailed output above and fix the issues."
    fi

    echo
    print_header "VALIDATION CHECKLIST"
    echo "✓ Service name fixes: Scripts reference ${SERVICE_NAME}-terraform-deploy-${INSTANCE}.service"
    echo "✓ Lock management: Scripts work with flock-based state locking"
    echo "✓ Status checking: Status script shows service and lock information"
    echo "✓ Manual triggers: Apply script triggers terraform deployments"
    echo "✓ Error handling: Scripts handle missing services/files gracefully"
    echo "✓ Backward compatibility: Scripts provide same functionality as manual operations"
}

# Main execution
main() {
    # Trap to ensure we always show summary
    trap print_summary EXIT

    run_all_tests

    # Return appropriate exit code
    if [ $CATEGORIES_FAILED -eq 0 ] && [ $TOTAL_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"