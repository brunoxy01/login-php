#!/bin/bash
set -e

# Send custom logs and metrics to Dynatrace
# Used to report test results and deployment events

# Required environment variables:
# - DT_API_TOKEN: Dynatrace API token with logs.ingest permission
# - DT_TENANT_URL: Dynatrace tenant URL (e.g., https://fov31014.live.dynatrace.com)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
# Log ingest API uses .live domain, workflows use .apps domain
LOG_TENANT_URL="${DT_TENANT_URL//.apps./.live.}"
LOG_INGEST_URL="${LOG_TENANT_URL}/api/v2/logs/ingest"
SERVICE_NAME="${SERVICE_NAME:-php_login}"
STAGE="${STAGE:-pre-production}"

# Validate required environment variables
if [ -z "$DT_API_TOKEN" ] || [ -z "$DT_TENANT_URL" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Required: DT_API_TOKEN, DT_TENANT_URL"
    exit 1
fi

# Function to send log entry
send_log() {
    local log_level=$1
    local message=$2
    local event_type=$3
    local additional_attributes=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    local log_payload=$(cat <<EOF
{
  "content": "$message",
  "severity": "$log_level",
  "timestamp": "$timestamp",
  "log.source": "github-actions",
  "service.name": "$SERVICE_NAME",
  "deployment.stage": "$STAGE",
  "event.type": "$event_type"
  $additional_attributes
}
EOF
)
    
    echo -e "${YELLOW}📝 Sending log to Dynatrace...${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$LOG_INGEST_URL" \
        -H "Authorization: Api-Token $DT_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$log_payload")
    
    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
        echo -e "${GREEN}✅ Log sent successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to send log (HTTP $HTTP_STATUS)${NC}"
        echo "Response: $(echo "$RESPONSE" | head -n-1)"
        return 1
    fi
}

# Parse command line arguments
LOG_LEVEL="${1:-INFO}"
MESSAGE="${2:-Deployment event}"
EVENT_TYPE="${3:-deployment}"

# Send the log
send_log "$LOG_LEVEL" "$MESSAGE" "$EVENT_TYPE" ""

echo -e "${GREEN}✅ Dynatrace log ingestion complete${NC}"
