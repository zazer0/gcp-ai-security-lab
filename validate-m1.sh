#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Module 1 Infrastructure Validation Script"
echo "=========================================="

# Check prerequisites
echo -e "\n${YELLOW}[1/7] Checking prerequisites...${NC}"

if [ -z "${PROJECT_ID:-}" ]; then
    echo -e "${RED}✗ ERROR: PROJECT_ID environment variable not set${NC}"
    echo "Please run: export PROJECT_ID=<your-project-id>"
    exit 1
fi
echo -e "${GREEN}✓ PROJECT_ID is set: $PROJECT_ID${NC}"

# Check for required tools
for tool in gcloud gsutil jq; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}✗ ERROR: $tool is not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required tools are installed${NC}"

# Test 1: Check dev bucket exists
echo -e "\n${YELLOW}[2/7] Checking modeldata-dev bucket...${NC}"
if gsutil ls gs://modeldata-dev-$PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✓ modeldata-dev bucket exists${NC}"
else
    echo -e "${RED}✗ modeldata-dev bucket not found${NC}"
    exit 1
fi

# Test 2: Check prod bucket exists
echo -e "\n${YELLOW}[3/7] Checking modeldata-prod bucket...${NC}"
if gsutil ls gs://modeldata-prod-$PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✓ modeldata-prod bucket exists${NC}"
else
    echo -e "${RED}✗ modeldata-prod bucket not found${NC}"
    exit 1
fi

# Test 3: Check service account key in dev bucket
echo -e "\n${YELLOW}[4/7] Checking for service account key in dev bucket...${NC}"
if gsutil ls gs://modeldata-dev-$PROJECT_ID/bucket-service-account.json &>/dev/null; then
    echo -e "${GREEN}✓ Service account key found in dev bucket${NC}"
else
    echo -e "${RED}✗ Service account key not found in dev bucket${NC}"
    exit 1
fi

# Test 4: Download and test service account key
echo -e "\n${YELLOW}[5/7] Testing service account key functionality...${NC}"
TEMP_KEY=$(mktemp)
gsutil cp gs://modeldata-dev-$PROJECT_ID/bucket-service-account.json $TEMP_KEY &>/dev/null

# Save current auth
ORIGINAL_ACCOUNT=$(gcloud config get-value account 2>/dev/null)

# Test the service account
gcloud auth activate-service-account --key-file=$TEMP_KEY &>/dev/null
if gcloud auth list --filter="status:ACTIVE" --format="value(account)" | grep -q "bucket-service-account"; then
    echo -e "${GREEN}✓ Service account authentication successful${NC}"
else
    echo -e "${RED}✗ Service account authentication failed${NC}"
    rm $TEMP_KEY
    exit 1
fi

# Test 5: Verify service account can access prod bucket
echo -e "\n${YELLOW}[6/7] Testing service account access to prod bucket...${NC}"
if gsutil ls gs://modeldata-prod-$PROJECT_ID/ &>/dev/null; then
    echo -e "${GREEN}✓ Service account can access prod bucket${NC}"
else
    echo -e "${RED}✗ Service account cannot access prod bucket${NC}"
    gcloud config set account $ORIGINAL_ACCOUNT &>/dev/null
    rm $TEMP_KEY
    exit 1
fi

# Test 6: Check for flag in prod bucket
echo -e "\n${YELLOW}[7/7] Checking for flag in prod bucket...${NC}"
if gsutil ls gs://modeldata-prod-$PROJECT_ID/secret_benchmarks/flag1_gpt5_benchmarks.txt &>/dev/null; then
    echo -e "${GREEN}✓ Flag file exists in prod bucket${NC}"
    
    # Download and display flag
    FLAG_CONTENT=$(gsutil cat gs://modeldata-prod-$PROJECT_ID/secret_benchmarks/flag1_gpt5_benchmarks.txt 2>/dev/null)
    echo -e "\n${GREEN}✓ Flag content: $FLAG_CONTENT${NC}"
else
    echo -e "${RED}✗ Flag not found in prod bucket${NC}"
    gcloud config set account $ORIGINAL_ACCOUNT &>/dev/null
    rm $TEMP_KEY
    exit 1
fi

# Restore original auth
gcloud config set account $ORIGINAL_ACCOUNT &>/dev/null
rm $TEMP_KEY

echo -e "\n${GREEN}=========================================="
echo "✓ Module 1 validation PASSED!"
echo "==========================================${NC}"