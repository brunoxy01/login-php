#!/bin/bash
set -e

# Dynatrace Integration Script
# Authenticates with Dynatrace OAuth2 and triggers validation workflow

# Required environment variables:
# - DT_CLIENT_ID: OAuth2 client ID
# - DT_CLIENT_SECRET: OAuth2 client secret
# - DT_TENANT_URL: Dynatrace tenant URL (e.g., https://fov31014.apps.dynatrace.com)
# - DT_WORKFLOW_ID: Workflow ID to trigger (default: 409c00f9-c459-4bd9-9fc5-e8464542d17f)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AUTH_URL="https://sso.dynatrace.com/sso/oauth2/token"
SCOPE="automation:workflows:run"
WORKFLOW_ID="${DT_WORKFLOW_ID:-409c00f9-c459-4bd9-9fc5-e8464542d17f}"
SERVICE_NAME="${SERVICE_NAME:-php_login}"
STAGE="${STAGE:-pre-production}"
TEST_DURATION="${TEST_DURATION:-5}"

# Validate required environment variables
if [ -z "$DT_CLIENT_ID" ] || [ -z "$DT_CLIENT_SECRET" ] || [ -z "$DT_TENANT_URL" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Required: DT_CLIENT_ID, DT_CLIENT_SECRET, DT_TENANT_URL"
    exit 1
fi

echo -e "${YELLOW}🔐 Authenticating with Dynatrace...${NC}"

# Step 1: Obtain OAuth2 token
TOKEN_RESPONSE=$(curl -s -X POST "$AUTH_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=$DT_CLIENT_ID&client_secret=$DT_CLIENT_SECRET&scope=$SCOPE")

# Extract access token
TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}❌ Failed to obtain authentication token${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"

# Step 2: Trigger Dynatrace validation workflow
echo -e "${YELLOW}🚀 Triggering Dynatrace validation workflow...${NC}"
echo "   Service: $SERVICE_NAME"
echo "   Stage: $STAGE"
echo "   Test Duration: $TEST_DURATION minutes"

WORKFLOW_URL="$DT_TENANT_URL/platform/automation/v1/workflows/$WORKFLOW_ID/run"
WORKFLOW_PAYLOAD=$(cat <<EOF
{
  "params": {
    "service": "$SERVICE_NAME",
    "stage": "$STAGE",
    "total_test_time": $TEST_DURATION
  }
}
EOF
)

WORKFLOW_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WORKFLOW_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    --data "$WORKFLOW_PAYLOAD")

# Extract HTTP status code and response body
HTTP_STATUS=$(echo "$WORKFLOW_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$WORKFLOW_RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
    echo -e "${GREEN}✅ Workflow triggered successfully${NC}"
    echo "Response: $RESPONSE_BODY"
    exit 0
else
    echo -e "${RED}❌ Failed to trigger workflow (HTTP $HTTP_STATUS)${NC}"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi
