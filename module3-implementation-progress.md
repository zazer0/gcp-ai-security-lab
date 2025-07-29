# Module 3 Implementation Progress Summary

## Overview
Successfully analyzed and fixed Module 3 implementation issues in the GCP CTF workshop, focusing on SSRF vulnerability exploitation via Cloud Functions.

## Key Technical Components

### Infrastructure
- **Cloud Function**: Gen2 function (Cloud Run service) with intentional SSRF vulnerability
- **Compute Instance**: Limited OAuth scopes (devstorage.read_only) to demonstrate privilege escalation
- **Service Accounts**: 
  - Compute account with restricted permissions
  - Function account with full cloud-platform scope (editor role)

### Vulnerability Design
- Cloud Function accepts user-controlled `metadata` parameter
- Function queries GCP metadata server with user input
- Returns flag4 when `metadata: "token"` is requested
- Exposes function's service account token enabling privilege escalation

## Issues Identified and Fixed

### 1. Function URL Portability
- **Problem**: Hardcoded function URL in `invoke_monitoring_function.sh`
- **Solution**: Dynamic URL retrieval using `gcloud run services describe`
- **Impact**: Script now works across different GCP projects/deployments

### 2. Gen1 vs Gen2 Function URLs
- **Problem**: Hint file showed outdated Gen1 URL format
- **Solution**: Updated to Gen2 Cloud Run service discovery method
- **Impact**: Accurate documentation for users

### 3. Validation Script Compatibility
- **Problem**: Status messages to stdout interfered with JSON parsing
- **Solution**: Redirected all status messages to stderr
- **Impact**: Validation script correctly parses function response

## Validation Results
- Core SSRF exploitation: ✓ Working
- Flag4 retrieval: ✓ Successful
- Privilege escalation demo: ✓ Verified
- Minor issues: Function source validation expects `main.py` (uploaded by setup script)

## Key Insights

### Architecture Decisions
- Gen2 functions deploy as Cloud Run services
- Function URLs follow pattern: `https://{name}-{hash}-{region}.a.run.app`
- Identity tokens required for authentication (not access tokens)

### Security Learning Objectives
1. Metadata server access from Cloud Functions
2. OAuth scope limitations bypass via SSRF
3. Service account token extraction for privilege escalation
4. Impact of overly permissive function service accounts

## Implementation Notes

### Critical Files
- `/terraform/module3.tf`: Infrastructure definition
- `/terraform/script/main.py`: Vulnerable function code
- `/invoke_monitoring_function.sh`: Function invocation helper
- `/validate-m3.sh`: Comprehensive validation script
- `/hints/module3.md`: User guidance

### Deployment Flow
1. Terraform creates infrastructure
2. `challenge-setup.sh` uploads `main.py` separately (for educational access)
3. Function deployed with editor role (intentionally overprivileged)
4. Compute instance restricted to storage read-only scope

## Next Steps for Scaling
- Ensure `challenge-setup.sh` is used for full deployment (not just terraform)
- Consider automating region configuration for multi-region deployments
- Document the Gen2 function behavior differences from Gen1
- Add monitoring to track successful exploitations for workshops