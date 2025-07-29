# Module 3 Implementation Summary

## Overview
This document summarizes the work completed to fix Module 3 validation issues in the GCP AI Security Lab CTF workshop.

## Key Issues Identified and Fixed

### 1. **Hardcoded Function URLs**
- **Problem**: `invoke_monitoring_function.sh` contained a hardcoded Gen2 Cloud Function URL that would break across different GCP projects
- **Solution**: Implemented dynamic URL retrieval using `gcloud run services describe`
- **Impact**: Script now works portably across any project deployment

### 2. **Incorrect Function URL Format in Documentation**
- **Problem**: `hints/module3.md` showed outdated Gen1 function URL format
- **Solution**: Updated to demonstrate Gen2 Cloud Run service discovery method
- **Impact**: Documentation now accurately reflects the deployed infrastructure

### 3. **Validation Script Output Parsing Issue**
- **Problem**: `validate-m3.sh` was capturing both stderr and stdout, breaking JSON parsing
- **Solution**: Removed `2>&1` redirection to capture only JSON output
- **Impact**: Validation script now correctly processes function responses

## Technical Details

### Gen2 Cloud Functions Architecture
- Gen2 functions are deployed as Cloud Run services
- URLs follow format: `https://[service-name]-[hash]-[region].a.run.app`
- Require identity tokens (not access tokens) for authentication
- Service discovery via: `gcloud run services describe [name] --region=[region]`

### SSRF Vulnerability Design
- Function accepts user-controlled `metadata` parameter
- Constructs metadata server URL: `http://metadata.google.internal/.../[user-input]`
- Allows extraction of function's service account token
- Demonstrates privilege escalation from limited VM scope to full cloud-platform access

### File Upload Strategy
- `challenge-setup.sh` uploads `main.py` separately after terraform deployment
- Ensures function source code is accessible from VM for analysis
- Aligns with `solution.md` expectations for the CTF challenge

## Implementation Changes

### invoke_monitoring_function.sh
```bash
# Added dynamic URL retrieval
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)')

# All status messages redirected to stderr
echo "Status message" >&2

# Only JSON response goes to stdout
echo $FUNCTION_RESPONSE
```

### validate-m3.sh
```bash
# Fixed: Removed stderr redirection
INVOKE_TEST=$(exec_on_vm "... && bash ./invoke_monitoring_function.sh")
# Previously: bash ./invoke_monitoring_function.sh 2>&1
```

## Validation Results
- **Before fixes**: 1 failure (invocation script output parsing)
- **After fixes**: All 24 validation checks passing
- Successfully validates:
  - VM OAuth scope limitations
  - Metadata server access
  - Function source code accessibility
  - SSRF vulnerability exploitation
  - Privilege escalation demonstration

## Key Learnings
- Gen2 Cloud Functions require different invocation patterns than Gen1
- Script output redirection must be carefully managed for parsing
- Dynamic service discovery improves deployment portability
- Validation scripts should separate status messages from data output