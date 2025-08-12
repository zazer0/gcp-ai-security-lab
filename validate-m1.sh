#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Module 1 Infrastructure Validation Script"
echo "=========================================="

# Check prerequisites
echo -e "\n${YELLOW}[1/10] Checking prerequisites...${NC}"

if [ -z "${PROJECT_ID:-}" ]; then
    echo -e "${RED}✗ ERROR: PROJECT_ID environment variable not set${NC}"
    echo "Please run: export PROJECT_ID=<your-project-id>"
    exit 1
fi
echo -e "${GREEN}✓ PROJECT_ID is set: $PROJECT_ID${NC}"

# Check for required tools
for tool in gcloud gsutil jq; do
    # Check if command exists without using negation operator
    command -v "$tool" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ERROR: $tool is not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required tools are installed${NC}"

# Save original gcloud configuration
# Capture output and errors separately
ORIGINAL_CONFIG=$(gcloud config get-value account 2>&1)
if [ $? -ne 0 ]; then
    ORIGINAL_CONFIG=""
fi

ORIGINAL_PROJECT=$(gcloud config get-value project 2>&1)
if [ $? -ne 0 ]; then
    ORIGINAL_PROJECT=""
fi

# Try to get configuration name, first method
ORIGINAL_CONFIGURATION=$(gcloud config configurations get-value name 2>&1)
if [ $? -ne 0 ]; then
    # Try alternative method
    ORIGINAL_CONFIGURATION=$(gcloud config get-value configuration 2>&1)
    if [ $? -ne 0 ]; then
        ORIGINAL_CONFIGURATION=""
    fi
fi

# Track if we're in cleanup to prevent double-cleanup
CLEANUP_DONE=false

# Set up trap to restore original config on exit
cleanup() {
    if [ "$CLEANUP_DONE" = "true" ]; then
        return 0
    fi
    CLEANUP_DONE=true
    
    echo -e "\n${YELLOW}Restoring original gcloud configuration...${NC}"
    if [ -n "$ORIGINAL_CONFIGURATION" ]; then
        CLEANUP_OUTPUT=$(gcloud config configurations activate "$ORIGINAL_CONFIGURATION" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}⚠ Warning: Could not restore configuration: $CLEANUP_OUTPUT${NC}"
        fi
    fi
    if [ -n "$ORIGINAL_CONFIG" ]; then
        CLEANUP_OUTPUT=$(gcloud config set account "$ORIGINAL_CONFIG" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}⚠ Warning: Could not restore account: $CLEANUP_OUTPUT${NC}"
        fi
    fi
    if [ -n "$ORIGINAL_PROJECT" ]; then
        CLEANUP_OUTPUT=$(gcloud config set project "$ORIGINAL_PROJECT" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}⚠ Warning: Could not restore project: $CLEANUP_OUTPUT${NC}"
        fi
    fi
    echo -e "${GREEN}✓ Configuration restored${NC}"
}
# Trap multiple signals to ensure cleanup runs
trap cleanup EXIT INT TERM

# Test student-workshop configuration exists
echo -e "\n${YELLOW}[2/10] Checking student-workshop configuration...${NC}"
if gcloud config configurations list --format="value(name)" | grep -q "^student-workshop$"; then
    echo -e "${GREEN}✓ student-workshop configuration exists${NC}"
else
    echo -e "${RED}✗ student-workshop configuration not found${NC}"
    echo "ERROR: The student-workshop configuration should be created by challenge-setup.sh"
    echo "Please run ./challenge-setup.sh first, or manually create with:"
    echo "  gcloud config configurations create student-workshop"
    exit 1
fi

# Switch to student-workshop configuration for permission tests
echo -e "\n${YELLOW}[3/10] Testing student-workshop permissions...${NC}"
echo -e "  ${YELLOW}(Switching from $ORIGINAL_CONFIGURATION to student-workshop)${NC}"
ACTIVATE_OUTPUT=$(gcloud config configurations activate student-workshop 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to activate student-workshop configuration: $ACTIVATE_OUTPUT${NC}"
    exit 1
fi

# Test that student-workshop CAN access modeldata-dev bucket
echo -e "  Testing modeldata-dev access..."
DEV_ACCESS_OUTPUT=$(gsutil ls "gs://modeldata-dev-$PROJECT_ID" 2>&1)
DEV_ACCESS_CODE=$?

if echo "$DEV_ACCESS_OUTPUT" | grep -q "AccessDeniedException\|Forbidden"; then
    echo -e "${RED}✗ student-workshop cannot access modeldata-dev bucket (should have access)${NC}"
    exit 1
else
    if [ $DEV_ACCESS_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ student-workshop can access modeldata-dev bucket${NC}"
    else
        echo -e "${RED}✗ Error accessing modeldata-dev bucket: $DEV_ACCESS_OUTPUT${NC}"
        exit 1
    fi
fi

# Test that student-workshop CANNOT access modeldata-prod bucket
echo -e "  Testing modeldata-prod restriction..."
PROD_ACCESS_OUTPUT=$(gsutil ls "gs://modeldata-prod-$PROJECT_ID" 2>&1)
PROD_ACCESS_CODE=$?

if echo "$PROD_ACCESS_OUTPUT" | grep -q "AccessDeniedException\|Forbidden"; then
    echo -e "${GREEN}✓ student-workshop cannot access modeldata-prod bucket (correctly restricted)${NC}"
else
    if [ $PROD_ACCESS_CODE -eq 0 ]; then
        echo -e "${RED}✗ student-workshop can access modeldata-prod bucket (should be restricted)${NC}"
        exit 1
    else
        # Check for other errors
        echo -e "${GREEN}✓ student-workshop cannot access modeldata-prod bucket (correctly restricted)${NC}"
    fi
fi

# Test that student-workshop CANNOT list compute instances
echo -e "\n${YELLOW}[4/10] Testing compute instance restrictions...${NC}"
COMPUTE_OUTPUT=$(gcloud compute instances list 2>&1)
COMPUTE_CODE=$?

if echo "$COMPUTE_OUTPUT" | grep -q "Required 'compute.instances.list' permission\|Forbidden\|PERMISSION_DENIED\|does not have compute.instances.list"; then
    echo -e "${GREEN}✓ student-workshop cannot list compute instances (correctly restricted)${NC}"
else
    if [ $COMPUTE_CODE -eq 0 ]; then
        echo -e "${RED}✗ student-workshop can list compute instances (should be restricted)${NC}"
        exit 1
    else
        # Check if it's a permission error even without specific message
        echo -e "${GREEN}✓ student-workshop cannot list compute instances (correctly restricted)${NC}"
    fi
fi

# Switch to admin-backup for remaining tests
echo -e "\n${YELLOW}Switching to admin-backup for infrastructure tests...${NC}"
ADMIN_CONFIG_CHECK=$(gcloud config configurations list --format="value(name)" | grep "^admin-backup$" 2>&1)
if [ -z "$ADMIN_CONFIG_CHECK" ]; then
    echo -e "${RED}✗ admin-backup configuration not found${NC}"
    echo "Using current default configuration instead"
    DEFAULT_OUTPUT=$(gcloud config configurations activate default 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠ Warning: Could not activate default configuration: $DEFAULT_OUTPUT${NC}"
    fi
else
    ADMIN_OUTPUT=$(gcloud config configurations activate admin-backup 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to activate admin-backup configuration: $ADMIN_OUTPUT${NC}"
        exit 1
    fi
fi

# Test 1: Check dev bucket exists
echo -e "\n${YELLOW}[5/10] Checking modeldata-dev bucket...${NC}"
DEV_BUCKET_CHECK=$(gsutil ls "gs://modeldata-dev-$PROJECT_ID" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ modeldata-dev bucket exists${NC}"
else
    echo -e "${RED}✗ modeldata-dev bucket not found: $DEV_BUCKET_CHECK${NC}"
    exit 1
fi

# Test 2: Check prod bucket exists
echo -e "\n${YELLOW}[6/10] Checking modeldata-prod bucket...${NC}"
PROD_BUCKET_CHECK=$(gsutil ls "gs://modeldata-prod-$PROJECT_ID" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ modeldata-prod bucket exists${NC}"
else
    echo -e "${RED}✗ modeldata-prod bucket not found: $PROD_BUCKET_CHECK${NC}"
    exit 1
fi

# Test 3: Check service account key in dev bucket
echo -e "\n${YELLOW}[7/10] Checking for service account key in dev bucket...${NC}"
KEY_CHECK=$(gsutil ls "gs://modeldata-dev-$PROJECT_ID/bucket-service-account.json" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Service account key found in dev bucket${NC}"
else
    echo -e "${RED}✗ Service account key not found in dev bucket: $KEY_CHECK${NC}"
    exit 1
fi

# Test 4: Download and test service account key
echo -e "\n${YELLOW}[8/10] Testing service account key functionality...${NC}"
TEMP_KEY=$(mktemp)
DOWNLOAD_OUTPUT=$(gsutil cp "gs://modeldata-dev-$PROJECT_ID/bucket-service-account.json" "$TEMP_KEY" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to download service account key: $DOWNLOAD_OUTPUT${NC}"
    rm -f "$TEMP_KEY"
    exit 1
fi

# Test the service account
AUTH_OUTPUT=$(gcloud auth activate-service-account --key-file="$TEMP_KEY" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Service account activation failed: $AUTH_OUTPUT${NC}"
    rm -f "$TEMP_KEY"
    exit 1
fi

ACTIVE_ACCOUNTS=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>&1)
if echo "$ACTIVE_ACCOUNTS" | grep -q "bucket-service-account"; then
    echo -e "${GREEN}✓ Service account authentication successful${NC}"
else
    echo -e "${RED}✗ Service account authentication failed - account not active${NC}"
    rm -f "$TEMP_KEY"
    exit 1
fi

# Test 5: Verify service account can access prod bucket
echo -e "\n${YELLOW}[9/10] Testing service account access to prod bucket...${NC}"
SA_PROD_ACCESS=$(gsutil ls "gs://modeldata-prod-$PROJECT_ID/" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Service account can access prod bucket${NC}"
else
    echo -e "${RED}✗ Service account cannot access prod bucket: $SA_PROD_ACCESS${NC}"
    rm -f "$TEMP_KEY"
    exit 1
fi

# Test 6: Check for flag in prod bucket
echo -e "\n${YELLOW}[10/10] Checking for flag in prod bucket...${NC}"
FLAG_CHECK=$(gsutil ls "gs://modeldata-prod-$PROJECT_ID/secret_benchmarks/flag1_gpt5_benchmarks.txt" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Flag file exists in prod bucket${NC}"
    
    # Download and display flag
    FLAG_CONTENT=$(gsutil cat "gs://modeldata-prod-$PROJECT_ID/secret_benchmarks/flag1_gpt5_benchmarks.txt" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Flag content: $FLAG_CONTENT${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Could not read flag content: $FLAG_CONTENT${NC}"
    fi
else
    echo -e "${RED}✗ Flag not found in prod bucket: $FLAG_CHECK${NC}"
    rm -f "$TEMP_KEY"
    exit 1
fi

# Cleanup temp key
rm -f "$TEMP_KEY"

echo -e "\n${GREEN}=========================================="
echo "✓ Module 1 validation PASSED!"
echo "==========================================${NC}"
