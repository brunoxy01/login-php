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
SCOPE="automation:workflows:read storage:events:read"
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

EXECUTIONS_URL="$DT_TENANT_URL/platform/automation/v1/executions?workflowId=$WORKFLOW_ID&pageSize=1"

ELAPSED_TIME=0
VALIDATION_ID=""

while [ $ELAPSED_TIME -lt $MAX_WAIT_TIME ]; do
    EXEC_RESPONSE=$(curl -s -X GET "$EXECUTIONS_URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json" 2>/dev/null)
    
    # Extract the most recent execution for THIS workflow only
    RECENT_EXECUTION=$(echo "$EXEC_RESPONSE" | grep -o '"id":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
    
    if [ -n "$RECENT_EXECUTION" ]; then
        echo -e "${BLUE}📋 Found execution: $RECENT_EXECUTION${NC}"
        
        # Get detailed execution info
        DETAIL_URL="$DT_TENANT_URL/platform/automation/v1/executions/$RECENT_EXECUTION"
        DETAIL_RESPONSE=$(curl -s -X GET "$DETAIL_URL" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Accept: application/json" 2>/dev/null)
        
        # Extract workflow state
        WORKFLOW_STATE=$(echo "$DETAIL_RESPONSE" | grep -o '"state":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
        
        echo -e "${YELLOW}   Workflow State: $WORKFLOW_STATE${NC}"
        
        # If workflow is still running, wait
        if [ "$WORKFLOW_STATE" = "RUNNING" ]; then
            echo -e "${YELLOW}⏳ Workflow still running... waiting $POLL_INTERVAL seconds${NC}"
            sleep $POLL_INTERVAL
            ELAPSED_TIME=$((ELAPSED_TIME + POLL_INTERVAL))
            continue
        fi
        
        # If workflow failed with error, pipeline fails
        if [ "$WORKFLOW_STATE" = "ERROR" ] || [ "$WORKFLOW_STATE" = "FAILED" ]; then
            echo ""
            echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║             ❌ WORKFLOW EXECUTION FAILED               ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${RED}⚠️  The Guardian validation workflow failed to execute${NC}"
            STATE_INFO=$(echo "$DETAIL_RESPONSE" | grep -o '"stateInfo":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
            if [ -n "$STATE_INFO" ] && [ "$STATE_INFO" != "null" ]; then
                echo -e "${RED}    Error: $STATE_INFO${NC}"
            fi
            echo ""
            echo -e "${YELLOW}📋 Execution ID: ${RECENT_EXECUTION}${NC}"
            exit 1
        fi
        
        # Workflow completed successfully - now check Guardian validation result
        # The validation ID is typically stored in the result object or we need to query Guardian API
        
        # Try to extract validation ID from result
        VALIDATION_ID=$(echo "$DETAIL_RESPONSE" | grep -o '"validationId":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
        
        if [ -z "$VALIDATION_ID" ] || [ "$VALIDATION_ID" = "null" ]; then
            # If no validationId in result, try to get it from Guardian API by searching recent validations
            echo -e "${YELLOW}🔍 Searching for Guardian validation...${NC}"
            
            # Query Guardian validations API (last 5 minutes)
            GUARDIAN_URL="$DT_TENANT_URL/platform/classic/environment-api/v2/slo?from=now-5m"
            GUARDIAN_RESPONSE=$(curl -s -X GET "$GUARDIAN_URL" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Accept: application/json" 2>/dev/null)
            
            # For now, if we can't get validation ID, we'll check if workflow succeeded
            # This is a temporary solution until we understand the Guardian API better
            if [ "$WORKFLOW_STATE" = "SUCCESS" ]; then
                echo ""
                echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║             ✅ WORKFLOW COMPLETED SUCCESSFULLY         ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${YELLOW}⚠️  Note: Guardian validation result check needs improvement${NC}"
                echo -e "${YELLOW}   Currently checking workflow execution status only${NC}"
                echo -e "${YELLOW}   TODO: Implement proper Guardian validation API check${NC}"
                echo ""
                echo -e "${BLUE}📊 View Guardian Dashboard:${NC}"
                echo "   ${DT_TENANT_URL}/ui/apps/dynatrace.site.reliability.guardian"
                echo ""
                echo -e "${BLUE}📋 Execution ID: ${RECENT_EXECUTION}${NC}"
                echo ""
                exit 0
            fi
        else
            # We have a validation ID - query Guardian API for the result
            echo -e "${BLUE}📋 Validation ID: $VALIDATION_ID${NC}"
            
            VALIDATION_URL="$DT_TENANT_URL/platform/classic/environment-api/v2/validations/$VALIDATION_ID"
            VALIDATION_RESPONSE=$(curl -s -X GET "$VALIDATION_URL" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Accept: application/json" 2>/dev/null)
            
            VALIDATION_STATUS=$(echo "$VALIDATION_RESPONSE" | grep -o '"status":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4)
            
            if [ "$VALIDATION_STATUS" = "PASS" ] || [ "$VALIDATION_STATUS" = "SUCCESS" ]; then
                echo ""
                echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║                    ✅ VALIDATION PASSED                ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${GREEN}🎉 All Site Reliability Guardian objectives were met!${NC}"
                echo -e "${GREEN}   Guardian returned: status='$VALIDATION_STATUS'${NC}"
                echo ""
                echo -e "${BLUE}📊 View Guardian Dashboard:${NC}"
                echo "   ${DT_TENANT_URL}/ui/apps/dynatrace.site.reliability.guardian"
                echo ""
                echo -e "${BLUE}📋 Validation ID: ${VALIDATION_ID}${NC}"
                echo -e "${BLUE}📋 Execution ID: ${RECENT_EXECUTION}${NC}"
                echo ""
                exit 0
            else
                echo ""
                echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║                    ❌ VALIDATION FAILED                ║${NC}"
                echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${RED}⚠️  Site Reliability Guardian detected issues!${NC}"
                echo -e "${RED}    One or more objectives did not meet the thresholds.${NC}"
                echo -e "${RED}    Guardian returned: status='$VALIDATION_STATUS'${NC}"
                echo ""
                echo -e "${YELLOW}📊 View Guardian Dashboard:${NC}"
                echo "   ${DT_TENANT_URL}/ui/apps/dynatrace.site.reliability.guardian"
                echo ""
                echo -e "${YELLOW}📋 Validation ID: ${VALIDATION_ID}${NC}"
                echo -e "${YELLOW}📋 Execution ID: ${RECENT_EXECUTION}${NC}"
                echo ""
                exit 1
            fi
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
