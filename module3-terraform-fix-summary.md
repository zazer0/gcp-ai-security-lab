# Module 3 Terraform Infrastructure Fix Summary

## Problem Statement
- Module 3 validation script failing with: "Extracted token does not have expected cloud-platform scope"
- Root cause: Cloud Function using same service account as VM (compute account with limited scopes)
- Privilege escalation demonstration broken - function token should have broader permissions than VM

## Solution Implemented
### Infrastructure Changes (terraform/module3.tf)

1. **Created Dedicated Service Account**
   ```hcl
   resource "google_service_account" "monitoring-function" {
     account_id   = "monitoring-function"
     display_name = "Monitoring Function Service Account"
     description  = "Service account for the monitoring cloud function with elevated permissions"
   }
   ```

2. **Granted Editor Role for cloud-platform Scope**
   ```hcl
   resource "google_project_iam_member" "monitoring-function-editor" {
     project = var.project_id
     role    = "roles/editor"
     member  = "serviceAccount:${google_service_account.monitoring-function.email}"
   }
   ```

3. **Updated Function Configuration**
   - Changed from: `service_account_email = data.google_service_account.compute-account-module3.email`
   - Changed to: `service_account_email = google_service_account.monitoring-function.email`

4. **Maintained Invocation Permissions**
   - Kept VM's compute account as invoker via `roles/run.invoker`
   - Ensures attack path remains viable

## Technical Context
### Attack Path Architecture
1. VM has limited OAuth scopes (`devstorage.read_only`)
2. VM can read function source code from storage bucket
3. Function has SSRF vulnerability exposing metadata endpoint
4. Function's service account has `cloud-platform` scope (Editor role)
5. Attacker extracts function token for privilege escalation

### Key Design Decisions
- **Editor Role**: Provides full `cloud-platform` scope needed for demonstration
- **Separate Accounts**: Clear privilege boundary between VM and function
- **Gen2 Functions**: Uses Cloud Run backend, requires `roles/run.invoker`

## Validation Script Compatibility
- Script expects token with `cloud-platform` scope
- New infrastructure provides this via Editor role
- All other validation checks remain compatible

## Deployment Steps
1. Run `terraform plan` to verify changes
2. Apply with `terraform apply`
3. Run validation script: `./validate-m3.sh`
4. Expected: All 22 checks should pass

## Insights for Scaling
1. **Service Account Scoping**: Critical for security boundaries in GCP
2. **Gen2 vs Gen1**: Different IAM models and authentication requirements
3. **Privilege Escalation**: Common pattern in cloud misconfigurations
4. **Validation Design**: Must match infrastructure assumptions exactly

## Files Modified
- `terraform/module3.tf`: Added service account, IAM binding, updated function config

## Dependencies
- Requires GCP project with sufficient permissions
- Gen2 Cloud Functions API enabled
- Cloud Run API enabled (for Gen2 functions)
- Existing compute service account must remain for VM operations

## Security Implications
- Intentionally vulnerable for CTF purposes
- Editor role on service account is excessive for production
- SSRF vulnerability in function code remains (by design)
- Demonstrates real-world privilege escalation risks