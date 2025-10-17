#!/bin/bash
# Database nuclear option script for aspen1

set -e

echo "🚀 OPTION 3: Complete Database Reset"
echo "=================================="

# Stop services via clan deployment (already done)
echo "✅ Services stopped via clan deployment"

# Manual data removal
echo "🗑️  Removing PostgreSQL data..."

# Remove PostgreSQL data directory
if [ -d "/var/lib/postgresql" ]; then
    echo "Removing /var/lib/postgresql/..."
    rm -rf /var/lib/postgresql/
    echo "✅ PostgreSQL data removed"
else
    echo "✅ PostgreSQL data already clean"
fi

# Remove Keycloak terraform directory
if [ -d "/var/lib/keycloak-adeci-terraform" ]; then
    echo "Removing /var/lib/keycloak-adeci-terraform/..."
    rm -rf /var/lib/keycloak-adeci-terraform/
    echo "✅ Keycloak terraform data removed"
else
    echo "✅ Keycloak terraform data already clean"
fi

# Remove any remaining Keycloak directories
find /var/lib -name '*keycloak*' -type d -exec rm -rf {} + 2>/dev/null || true
find /tmp -name '*keycloak*' -type d -exec rm -rf {} + 2>/dev/null || true
find /var/cache -name '*postgres*' -type d -exec rm -rf {} + 2>/dev/null || true

echo "🧹 Cache and temp cleanup complete"
echo ""
echo "🎯 Database completely nuked!"
echo "Ready for truly fresh Keycloak deployment"