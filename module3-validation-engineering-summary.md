# Module 3 Validation Engineering Summary

## Overview
Successfully debugged and fixed Module 3 infrastructure validation for a GCP CTF workshop demonstrating SSRF-based privilege escalation. The module teaches how limited VM access can be escalated to full GCP project access through a vulnerable cloud function.

## Key Technical Challenges Resolved

### 1. OAuth Scopes vs IAM Roles Confusion
- **Issue**: VM's compute service account has limited OAuth scopes preventing Cloud Run API calls
- **Key Insight**: OAuth scopes are VM-level restrictions set at creation time - IAM roles cannot expand them
- **Solution**: Hard-coded Gen2 function URL in invocation script to bypass need for `gcloud run services describe`
- **Impact**: Critical for understanding GCP security boundaries in CTF scenarios

### 2. Gen1 to Gen2 Cloud Functions Migration
- **Issue**: Legacy function URLs (`https://{region}-{project}.cloudfunctions.net/{function}`) no longer valid
- **Reality**: Gen2 functions are Cloud Run services with format `https://{function}-{hash}-{region}.a.run.app`
- **Challenge**: Dynamic hash makes URL discovery difficult with limited OAuth scopes
- **Solution**: Store function URL as terraform output or hard-code for CTF scenarios

### 3. Nested JSON Token Extraction
- **Issue**: Cloud function returns token as escaped JSON string within `function_account` field
- **Format**: `{"function_account": "{\"access_token\":\"ya29...\",\"expires_in\":3599,\"token_type\":\"Bearer\"}"}`
- **Initial Approach**: Simple grep/cut commands failed on escaped quotes
- **Solution**: Multi-step parsing with sed to unescape JSON, plus jq fallback for robustness

## Attack Path Validated
1. **Initial Access**: SSH to VM with default compute service account
2. **Discovery**: VM has `devstorage.read_only` scope, can't access most GCP APIs
3. **Enumeration**: List buckets, find `cloud-function-bucket-module3` with source code
4. **Code Analysis**: Identify SSRF in `main.py` - user controls metadata endpoint path
5. **Exploitation**: Request `/token` endpoint via function's SSRF vulnerability
6. **Privilege Escalation**: Extract function's service account token with `cloud-platform` scope
7. **Impact**: Full GCP project access from initially limited VM

## Critical Files & Components

### Infrastructure (Terraform)
- `terraform/module3.tf`: Defines Gen2 cloud function, service accounts, IAM bindings
- `terraform/script/main.py`: Vulnerable function with SSRF in metadata endpoint
- Key Resources:
  - `monitoring-function` service account with `roles/editor`
  - Gen2 Cloud Function exposing metadata endpoint
  - Storage bucket with function source (readable by VM)

### Validation & Exploitation
- `validate-m3.sh`: Comprehensive 24-point validation script
  - Tests VM connectivity, OAuth scopes, storage access
  - Validates SSRF exploitation and privilege escalation
  - Includes robust JSON parsing with sed/jq fallback
- `invoke_monitoring_function.sh`: Exploit script with hard-coded function URL
- `solution.md`: Updated with Gen2-compatible commands

## Implementation Insights for Scaling

### 1. Environment Setup Requirements
- Must set `PROJECT_ID` and `LOCATION` environment variables
- Requires gcloud CLI authenticated with project access
- SSH key setup for VM access (handled by gcloud)

### 2. Common Failure Points
- **OAuth Scope Limitations**: VMs need explicit scopes at creation for API access
- **Function URL Discovery**: Gen2 URLs not discoverable without Cloud Run API access
- **JSON Parsing**: Escaped JSON in responses requires careful handling
- **IAM Propagation**: New bindings may take 60+ seconds to propagate

### 3. Automation Considerations
- Validation script auto-copies invocation script to VM
- Multiple parsing methods for reliability (sed primary, jq fallback)
- Color-coded output for quick issue identification
- Exit codes for CI/CD integration

### 4. Security Teaching Points
- Demonstrates real privilege escalation technique
- Shows importance of least privilege for cloud functions
- Illustrates metadata server as attack vector
- Highlights OAuth scope boundaries in GCP

## Replication Checklist
1. Deploy infrastructure with `terraform apply`
2. Ensure environment variables set: `PROJECT_ID`, `LOCATION`
3. Run `validate-m3.sh` to verify setup
4. If validation fails, check:
   - Function URL in `invoke_monitoring_function.sh`
   - VM SSH access and OAuth scopes
   - IAM binding propagation (wait 60s)
   - JSON parsing logic for your shell environment
5. Use validation output to debug specific failures

## Future Improvements
- Store Gen2 function URLs as terraform outputs
- Add retry logic for transient GCP API failures
- Consider VM creation with `cloud-platform.read-only` scope
- Package as containerized environment for consistency
- Add timing metrics for performance baseline