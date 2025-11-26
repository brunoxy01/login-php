#!/bin/bash
# Check Dynatrace Guardian Validation Result
# Polls the validation result and exits with success/failure based on Guardian status

set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUTH_URL="https://sso.dynatrace.com/sso/oauth2/token"
SCOPE="automation:workflows:read"
DT_TENANT_URL="${DT_TENANT_URL:-https://fov31014.apps.dynatrace.com}"
WORKFLOW_ID="${DT_WORKFLOW_ID:-409c00f9-c459-4bd9-9fc5-e8464542d17f}"
MAX_WAIT_TIME="${MAX_WAIT_TIME:-300}"  # 5 minutes max wait (configurable)
POLL_INTERVAL="${POLL_INTERVAL:-15}"    # Check every 15 seconds
FAIL_ON_TIMEOUT="${FAIL_ON_TIMEOUT:-true}"  # Fail pipeline if timeout (recommended)

# Validate required environment variables
if [ -z "$DT_CLIENT_ID" ] || [ -z "$DT_CLIENT_SECRET" ] || [ -z "$DT_TENANT_URL" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Required: DT_CLIENT_ID, DT_CLIENT_SECRET, DT_TENANT_URL"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Dynatrace Site Reliability Guardian - Validation     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}⏱️  Timeout: ${MAX_WAIT_TIME}s ($(($MAX_WAIT_TIME / 60)) minutes)${NC}"
echo -e "${BLUE}🔄 Poll interval: ${POLL_INTERVAL}s${NC}"
echo ""

echo -e "${YELLOW}🔐 Authenticating with Dynatrace...${NC}"

# Step 1: Obtain OAuth2 token
AUTH_FULL_RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$AUTH_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=$DT_CLIENT_ID&client_secret=$DT_CLIENT_SECRET&scope=$SCOPE")

AUTH_HTTP_STATUS=$(echo "$AUTH_FULL_RESPONSE" | grep "HTTP_STATUS_CODE:" | cut -d: -f2)
AUTH_RESPONSE_BODY=$(echo "$AUTH_FULL_RESPONSE" | grep -v "HTTP_STATUS_CODE:")

if [ -z "$AUTH_HTTP_STATUS" ] || [ "$AUTH_HTTP_STATUS" = "000" ]; then
    echo -e "${RED}❌ Failed to connect to OAuth endpoint${NC}"
    exit 1
fi

if [ "$AUTH_HTTP_STATUS" -lt 200 ] || [ "$AUTH_HTTP_STATUS" -ge 300 ]; then
    echo -e "${RED}❌ Authentication failed (HTTP $AUTH_HTTP_STATUS)${NC}"
    exit 1
fi

TOKEN=$(echo "$AUTH_RESPONSE_BODY" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}❌ Failed to obtain authentication token${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"
echo ""

# Step 2: Query recent workflow executions
echo -e "${YELLOW}🔍 Querying recent workflow executions...${NC}"

EXECUTIONS_URL="$DT_TENANT_URL/platform/automation/v1/executions?workflowId=$WORKFLOW_ID&pageSize=5"

ELAPSED_TIME=0
VALIDATION_FOUND=false

while [ $ELAPSED_TIME -lt $MAX_WAIT_TIME ]; do
    EXEC_RESPONSE=$(curl -s -X GET "$EXECUTIONS_URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json" 2>/dev/null)
    
    # Extract the most recent execution (suppress grep warnings)
    RECENT_EXECUTION=$(echo "$EXEC_RESPONSE" | grep -o '"id":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
    
    if [ -n "$RECENT_EXECUTION" ]; then
        echo -e "${BLUE}📋 Found execution: $RECENT_EXECUTION${NC}"
        
        # Get detailed execution info
        DETAIL_URL="$DT_TENANT_URL/platform/automation/v1/executions/$RECENT_EXECUTION"
        DETAIL_RESPONSE=$(curl -s -X GET "$DETAIL_URL" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Accept: application/json" 2>/dev/null)
        
        # Extract status (Dynatrace uses "state" field)
        STATUS=$(echo "$DETAIL_RESPONSE" | grep -o '"state":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
        
        echo -e "${YELLOW}   Status: $STATUS${NC}"
        
        # Comparison logic - this is where we check Guardian result
        if [ "$STATUS" = "RUNNING" ]; then
            echo -e "${YELLOW}⏳ Validation still running... waiting $POLL_INTERVAL seconds${NC}"
            sleep $POLL_INTERVAL
            ELAPSED_TIME=$((ELAPSED_TIME + POLL_INTERVAL))
            continue
        fi
        
        # ✅ SUCCESS: Pipeline will PASS (exit 0)
        if [ "$STATUS" = "SUCCESS" ]; then
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                    ✅ VALIDATION PASSED                ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${GREEN}🎉 All Site Reliability Guardian objectives were met!${NC}"
            echo -e "${GREEN}   Guardian returned: state='SUCCESS'${NC}"
            echo ""
            echo -e "${BLUE}📊 View Guardian Dashboard:${NC}"
            echo "   ${DT_TENANT_URL}/ui/apps/dynatrace.site.reliability.guardian"
            echo ""
            echo -e "${BLUE}📋 Execution ID: ${RECENT_EXECUTION}${NC}"
            echo ""
            VALIDATION_FOUND=true
            exit 0
        # ❌ ERROR/FAILED: Pipeline will FAIL (exit 1)
        elif [ "$STATUS" = "ERROR" ] || [ "$STATUS" = "FAILED" ]; then
            echo ""
            echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║                    ❌ VALIDATION FAILED                ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${RED}⚠️  Site Reliability Guardian detected issues!${NC}"
            echo -e "${RED}    One or more objectives did not meet the thresholds.${NC}"
            echo -e "${RED}    Guardian returned: state='$STATUS'${NC}"
            echo ""
            echo -e "${YELLOW}📊 View Guardian Dashboard:${NC}"
            echo "   ${DT_TENANT_URL}/ui/apps/dynatrace.site.reliability.guardian"
            echo ""
            echo -e "${YELLOW}📋 Execution ID: ${RECENT_EXECUTION}${NC}"
            echo ""
            echo -e "${YELLOW}🔍 Check: Errors, Latency, Saturation, or User Type validation${NC}"
            VALIDATION_FOUND=true
            exit 1
        fi
    fi
    
    if [ $ELAPSED_TIME -eq 0 ]; then
        echo -e "${YELLOW}⏳ Waiting for validation to start...${NC}"
    fi
    
    sleep $POLL_INTERVAL
    ELAPSED_TIME=$((ELAPSED_TIME + POLL_INTERVAL))
done

# Timeout reached - validation didn't complete in time
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                    ⏱️  VALIDATION TIMEOUT              ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  Could not determine validation result within ${MAX_WAIT_TIME}s ($(($MAX_WAIT_TIME / 60)) minutes)${NC}"
echo -e "${YELLOW}   The validation may still be running in Dynatrace.${NC}"
echo ""
echo -e "${YELLOW}📊 Check manually: $DT_TENANT_URL/ui/apps/dynatrace.site.reliability.guardian${NC}"
echo ""

# Decide whether to fail or continue on timeout
if [ "$FAIL_ON_TIMEOUT" = "true" ]; then
    echo -e "${RED}❌ Pipeline FAILED due to timeout${NC}"
    echo -e "${RED}   Validation did not complete within ${MAX_WAIT_TIME}s${NC}"
    exit 1
else
    echo -e "${YELLOW}⚠️  Pipeline continues despite timeout (FAIL_ON_TIMEOUT=false)${NC}"
    echo -e "${YELLOW}   This is not recommended - validation status unknown${NC}"
    exit 0
fi
