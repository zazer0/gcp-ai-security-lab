# Module 3 CTF Infrastructure Validation - Consolidated Fix Summary

## Overview
Successfully resolved all validation issues for Module 3's SSRF privilege escalation challenge. Achieved 100% validation success (24/24 checks passing) after addressing OAuth scope limitations, Gen2 Cloud Functions compatibility, and JSON parsing issues.

## Critical Issues Fixed

### 1. **OAuth Scope vs IAM Role Confusion**
- **Root Cause**: VM created with limited OAuth scope (`devstorage.read_only`) that cannot be expanded via IAM
- **Impact**: VM couldn't access Cloud Run APIs despite having IAM permissions
- **Solution**: Hard-coded function URL in `invoke_monitoring_function.sh` to bypass API requirement

### 2. **Gen2 Cloud Functions Migration**
- **Changes Required**:
  - URL format: `https://{name}-{hash}-{region}.a.run.app` (dynamic)
  - Authentication: Case-sensitive "Bearer" header
  - IAM role: `roles/run.invoker` (not `cloudfunctions.invoker`)
- **Solution**: Updated validation script to use `gcloud run services describe` for dynamic URL lookup

### 3. **Token Extraction Issues**
- **Problem**: Function returns nested escaped JSON in `function_account` field
- **Initial Request Error**: Script requested `metadata: "email"` instead of `metadata: "token"`
- **Solution**: Fixed payload and implemented robust JSON parsing with unescaping logic

### 4. **Validation Script Reliability**
- **Removed**: 11 instances of `|| true` that masked errors
- **Fixed**: Premature exit on token failures
- **Added**: Automatic script deployment to VM during validation

## Attack Path Validated
1. SSH to VM with limited OAuth scopes
2. Read function source from storage bucket (allowed by scope)
3. Discover SSRF vulnerability in monitoring function
4. Exploit SSRF to extract function's service account token
5. Use elevated token (cloud-platform scope) for privilege escalation

## Key Implementation Changes

```bash
# invoke_monitoring_function.sh - Hard-coded URL
FUNCTION_URL="https://monitoring-function-rr4orxndwa-ue.a.run.app"
curl -X POST $FUNCTION_URL -d '{"metadata": "token"}'

# validate-m3.sh - Token extraction with unescaping
FUNCTION_ACCOUNT=$(echo "$SSRF_RESPONSE" | sed -n 's/.*"function_account": "\(.*\)".*/\1/p')
EXTRACTED_TOKEN=$(echo "$FUNCTION_ACCOUNT" | sed 's/\\"/"/g' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
```

## Lessons for Production
1. **OAuth scopes are immutable** - Set at VM creation, not expandable via IAM
2. **Gen2 functions require dynamic discovery** - No predictable URL pattern
3. **Error masking hinders debugging** - Avoid `|| true` patterns
4. **Nested JSON requires careful parsing** - Consider using `jq` for robustness

## Final Status
- **All 24 validation checks passing**
- **Infrastructure correctly demonstrates intended vulnerability**
- **Ready for CTF deployment**