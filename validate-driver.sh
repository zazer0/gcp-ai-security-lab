#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Module 1 Validation Driver Script"
echo "=========================================="

# Check PROJECT_ID is set
if [ -z "${PROJECT_ID:-}" ]; then
    echo -e "${RED}✗ ERROR: PROJECT_ID environment variable not set${NC}"
    echo "Please run: export PROJECT_ID=<your-project-id>"
    exit 1
fi

# Step 1: Verify student-workshop config is active
echo -e "\n${YELLOW}[1/6] Verifying current configuration...${NC}"
CURRENT_CONFIG=$(gcloud config configurations list --filter="is_active=true" --format="value(name)" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ERROR: Failed to get current configuration: $CURRENT_CONFIG${NC}"
    exit 1
fi

if [ "$CURRENT_CONFIG" != "student-workshop" ]; then
    echo -e "${RED}✗ ERROR: Current configuration is '$CURRENT_CONFIG', not 'student-workshop'${NC}"
    echo "Please activate student-workshop configuration first:"
    echo "  gcloud config configurations activate student-workshop"
    exit 1
fi
echo -e "${GREEN}✓ student-workshop configuration is active${NC}"

# Step 2: Save original configuration details
echo -e "\n${YELLOW}[2/6] Saving original configuration details...${NC}"
ORIGINAL_ACCOUNT=$(gcloud config get-value account 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ERROR: Failed to get account from student-workshop: $ORIGINAL_ACCOUNT${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Account saved: $ORIGINAL_ACCOUNT${NC}"

# Step 3: Create temporary validation configuration
echo -e "\n${YELLOW}[3/6] Creating validation configuration...${NC}"

# Check if validation config already exists and delete it
if gcloud config configurations list --format="value(name)" 2>/dev/null | grep -q "^validation$"; then
    echo -e "  ${YELLOW}Removing existing validation configuration...${NC}"
    DELETE_OUTPUT=$(gcloud config configurations delete validation --quiet 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ERROR: Failed to delete existing validation config: $DELETE_OUTPUT${NC}"
        exit 1
    fi
fi

# Create new validation configuration
CREATE_OUTPUT=$(gcloud config configurations create validation 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ERROR: Failed to create validation configuration: $CREATE_OUTPUT${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Created validation configuration${NC}"

# Configure validation with account and project
echo -e "  Setting account..."
SET_ACCOUNT_OUTPUT=$(gcloud config set account "student-workshop@${PROJECT_ID}.iam.gserviceaccount.com" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ERROR: Failed to set account: $SET_ACCOUNT_OUTPUT${NC}"
    # Cleanup on failure
    gcloud config configurations activate student-workshop 2>/dev/null
    gcloud config configurations delete validation --quiet 2>/dev/null
    exit 1
fi

echo -e "  Setting project..."
SET_PROJECT_OUTPUT=$(gcloud config set project "$PROJECT_ID" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ERROR: Failed to set project: $SET_PROJECT_OUTPUT${NC}"
    # Cleanup on failure
    gcloud config configurations activate student-workshop 2>/dev/null
    gcloud config configurations delete validation --quiet 2>/dev/null
    exit 1
fi
echo -e "${GREEN}✓ Validation configuration ready${NC}"

# Step 4: Run validation script
echo -e "\n${YELLOW}[4/6] Running validation tests...${NC}"
echo "=========================================="

# Run validate-m1.sh and capture exit code
./validate-m1.sh
VALIDATION_EXIT_CODE=$?

echo "=========================================="

# Step 5: Restore original configuration
echo -e "\n${YELLOW}[5/6] Restoring original configuration...${NC}"
RESTORE_OUTPUT=$(gcloud config configurations activate student-workshop 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠ Warning: Failed to restore student-workshop: $RESTORE_OUTPUT${NC}"
    echo "  You may need to manually activate it:"
    echo "  gcloud config configurations activate student-workshop"
else
    echo -e "${GREEN}✓ Restored student-workshop configuration${NC}"
fi

# Step 6: Clean up validation configuration
echo -e "\n${YELLOW}[6/7] Cleaning up validation configuration...${NC}"
DELETE_OUTPUT=$(gcloud config configurations delete validation --quiet 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠ Warning: Failed to delete validation config: $DELETE_OUTPUT${NC}"
    echo "  You may need to manually delete it:"
    echo "  gcloud config configurations delete validation"
else
    echo -e "${GREEN}✓ Deleted validation configuration${NC}"
fi

# Step 7: Clean up bucket-service-account.json if it exists
echo -e "\n${YELLOW}[7/7] Cleaning up bucket-service-account.json file...${NC}"
if [ -f "./bucket-service-account.json" ]; then
    rm -f ./bucket-service-account.json
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Deleted bucket-service-account.json file${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Failed to delete bucket-service-account.json${NC}"
        echo "  You may need to manually delete it:"
        echo "  rm ./bucket-service-account.json"
    fi
else
    echo -e "${YELLOW}ℹ No bucket-service-account.json file found to clean up${NC}"
fi

# Exit with same code as validation script
if [ $VALIDATION_EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}=========================================="
    echo "✓ Validation completed successfully!"
    echo "==========================================${NC}"
else
    echo -e "\n${RED}=========================================="
    echo "✗ Validation failed with exit code: $VALIDATION_EXIT_CODE"
    echo "==========================================${NC}"
fi

exit $VALIDATION_EXIT_CODE
