#!/bin/bash
# Test script for Dynatrace integration

set -e

echo "🧪 Testing Dynatrace Integration Locally"
echo "========================================"
echo ""

# Check if credentials are set
if [ -z "$DT_CLIENT_ID" ] || [ -z "$DT_CLIENT_SECRET" ]; then
    echo "❌ Missing Dynatrace OAuth2 credentials"
    echo ""
    echo "Please set these environment variables:"
    echo ""
    echo "export DT_CLIENT_ID='dt0s02.T4USOJ3A'  # (example from Igor)"
    echo "export DT_CLIENT_SECRET='dt0s02.T4USOJ3A.KDDL...'"
    echo "export DT_TENANT_URL='https://fov31014.apps.dynatrace.com'"
    echo ""
    echo "Then run this script again."
    exit 1
fi

if [ -z "$DT_TENANT_URL" ]; then
    export DT_TENANT_URL="https://fov31014.apps.dynatrace.com"
    echo "ℹ️  Using default tenant: $DT_TENANT_URL"
fi

echo "✅ Credentials configured"
echo "   Client ID: ${DT_CLIENT_ID:0:15}..."
echo "   Tenant: $DT_TENANT_URL"
echo ""

# Test 1: Trigger workflow
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test 1: Triggering Dynatrace Workflow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

export SERVICE_NAME="php_login"
export STAGE="pre-production"
export TEST_DURATION=5

./scripts/trigger_dynatrace_validation.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test completed!"
echo ""
echo "Check Dynatrace tenant for:"
echo "  • Workflow execution in Automation section"
echo "  • Logs in Logs & Events"
echo ""
echo "URL: $DT_TENANT_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
