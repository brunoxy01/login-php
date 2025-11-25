#!/bin/bash
# Helper script to configure GitHub secrets
# This script helps you prepare the values needed for GitHub secrets

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     GitHub Secrets Configuration Helper for K8s Deployment    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section header
print_section() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to show secret configuration
show_secret() {
    local name=$1
    local value=$2
    echo -e "${GREEN}Name:${NC}  $name"
    echo -e "${GREEN}Value:${NC} $value"
    echo ""
}

# ============================================================================
# 1. Docker Registry Secrets
# ============================================================================
print_section "1️⃣  DOCKER REGISTRY SECRETS"

echo "Using GitHub Container Registry (ghcr.io)"
echo ""
show_secret "DOCKER_REGISTRY" "ghcr.io"

echo "Your GitHub username (repository owner):"
GITHUB_USER=$(git config remote.origin.url | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')
if [ -n "$GITHUB_USER" ]; then
    echo -e "${GREEN}Detected from git remote:${NC} $GITHUB_USER"
    show_secret "DOCKER_USERNAME" "$GITHUB_USER"
else
    echo -e "${YELLOW}Could not detect. Please enter your GitHub username:${NC}"
    read -r GITHUB_USER
    show_secret "DOCKER_USERNAME" "$GITHUB_USER"
fi

echo -e "${YELLOW}For DOCKER_PASSWORD:${NC}"
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Generate new token (classic)"
echo "3. Select scopes: write:packages, read:packages, delete:packages"
echo "4. Copy the generated token"
echo ""
echo -e "${RED}⚠️  Keep this token safe! You'll add it as DOCKER_PASSWORD secret${NC}"
echo ""

# ============================================================================
# 2. Kubernetes Config
# ============================================================================
print_section "2️⃣  KUBERNETES CONFIGURATION"

echo "Checking if kubectl is available..."
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓ kubectl found${NC}"
    echo ""
    
    # Check current context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
    echo -e "${GREEN}Current context:${NC} $CURRENT_CONTEXT"
    
    if [ "$CURRENT_CONTEXT" != "none" ]; then
        echo ""
        echo "Generating base64-encoded kubeconfig..."
        echo ""
        
        # Generate kubeconfig
        KUBE_CONFIG_B64=$(kubectl config view --minify --flatten | base64 | tr -d '\n')
        
        echo -e "${GREEN}✓ Kubeconfig generated${NC}"
        echo ""
        show_secret "KUBE_CONFIG" "${KUBE_CONFIG_B64:0:50}... (truncated)"
        
        echo "Full value saved to: ./kube_config.b64"
        echo "$KUBE_CONFIG_B64" > ./kube_config.b64
        echo ""
        echo -e "${YELLOW}Copy the content of ./kube_config.b64 to GitHub secret KUBE_CONFIG${NC}"
    else
        echo -e "${RED}✗ No kubectl context configured${NC}"
        echo "Please configure kubectl to connect to your cluster first"
    fi
else
    echo -e "${RED}✗ kubectl not found${NC}"
    echo "Please install kubectl and configure access to your cluster"
fi
echo ""

# ============================================================================
# 3. Dynatrace Secrets
# ============================================================================
print_section "3️⃣  DYNATRACE SECRETS"

echo "You need to configure these in Dynatrace tenant:"
echo ""

echo -e "${BLUE}OAuth2 Credentials (for workflow triggers):${NC}"
echo "1. Go to: Dynatrace → Settings → Access Tokens → OAuth clients"
echo "2. Create new OAuth client"
echo "3. Scopes: automation:workflows:run"
echo ""
show_secret "DT_CLIENT_ID" "dt0s02.XXXXXXXX"
show_secret "DT_CLIENT_SECRET" "dt0s02.XXXXXXXX.XXXX..."

echo -e "${BLUE}API Token (for log ingestion):${NC}"
echo "1. Go to: Dynatrace → Settings → Access Tokens → API tokens"
echo "2. Generate new token"
echo "3. Scopes: logs.ingest, metrics.ingest"
echo ""
show_secret "DT_API_TOKEN" "dt0c01.XXXXXXXX.XXXX..."

echo -e "${BLUE}Tenant URL:${NC}"
echo "Example: https://abc12345.live.dynatrace.com"
echo "       or: https://abc12345.apps.dynatrace.com"
echo ""
show_secret "DT_TENANT_URL" "https://your-tenant.live.dynatrace.com"

echo -e "${BLUE}Workflow ID (optional):${NC}"
echo "1. Go to: Dynatrace → Automation → Workflows"
echo "2. Open your validation workflow"
echo "3. Copy ID from URL"
echo ""
show_secret "DT_WORKFLOW_ID" "409c00f9-c459-4bd9-9fc5-e8464542d17f"

# ============================================================================
# Summary
# ============================================================================
print_section "📋 SUMMARY - Secrets to Configure in GitHub"

echo "Go to: https://github.com/$GITHUB_USER/$(basename $(git rev-parse --show-toplevel))/settings/secrets/actions"
echo ""
echo "Add these secrets (click 'New repository secret' for each):"
echo ""
echo "Docker Registry:"
echo "  • DOCKER_REGISTRY"
echo "  • DOCKER_USERNAME"
echo "  • DOCKER_PASSWORD"
echo ""
echo "Kubernetes:"
echo "  • KUBE_CONFIG"
echo ""
echo "Dynatrace:"
echo "  • DT_CLIENT_ID"
echo "  • DT_CLIENT_SECRET"
echo "  • DT_API_TOKEN"
echo "  • DT_TENANT_URL"
echo "  • DT_WORKFLOW_ID (optional)"
echo ""

echo -e "${GREEN}✅ Configuration helper completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure all secrets in GitHub"
echo "2. Ensure Dynatrace OneAgent Operator is installed in your K8s cluster"
echo "3. Push your branch and create a Pull Request"
echo "4. After merge to main, the pipeline will deploy automatically"
echo ""
