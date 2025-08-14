# Flag Files Terraform Integration Summary

## Overview
Successfully integrated CTF-style flag files across all GCP AI Security Lab modules, automating flag deployment through Terraform configuration and setup scripts. This creates discoverable flags that match the portal's progressive module unlocking system.

## Technical Implementation

### Variable Configuration Updates
- **terraform/variables.tf**: Updated default flag values to match actual discoverable content
  - `flag1_value`: `"flag{found-the-lazy-dev}"` (was `"flag{dev_bucket_found}"`)
  - `flag2_value`: `"flag{found-the-secret-infrastructure}"` (was `"flag{terraform_state_accessed}"`)

### Module 1: Storage Enumeration Flags
- **Primary Flag**:
  - **File**: `mod1-setup.sh` (lines 26-28)
  - **Location**: `gs://modeldata-dev-{project}/flag1.txt`
  - **Content**: `"flag{found-the-lazy-dev}"`
  - **Discovery Context**: Found alongside leaked service account credentials in dev bucket

- **flag1-partB.txt**:
  - **File**: `mod1-setup.sh` (lines 59-60)
  - **Location**: `gs://modeldata-prod-{project}/flag1-partB.txt`
  - **Content**: `"well-done-what-else-can-you-access"`
  - **Discovery Context**: Found after using leaked service account to access prod bucket

- **Educational Purpose**: Teaches bucket enumeration, credential discovery, and service account privilege testing

### Module 2: Infrastructure State Flag  
- **File**: `mod2-setup.sh` (lines 24-26)
- **Location**: `gs://file-uploads-{project}/flag2.txt`
- **Content**: `"flag{found-the-secret-infrastructure}"`
- **Discovery Context**: Found alongside exposed terraform.tfstate file
- **Educational Purpose**: Demonstrates risks of exposed infrastructure configuration

-### Module 3: VM Exploitation Flags
**Flag2 Part B - VM Flag**:
- **File**: `mod2-setup.sh` (lines 32-34)
- **Location**: VM `/home/alice/flag2-partB.txt`
- **Content**: `"good-job-now-look-around"`
- **Discovery Context**: Found after SSH access via leaked keys + IP

- **Part C - Cloud Function Bucket Flag**:
### Module 3: SSRF and Metadata Exploitation Flags
- **flag2-part-C.txt**:
  - **File**: `terraform/module3.tf` (lines 38-42)
  - **Location**: `gs://cloud-function-bucket-module3-{project}/flag2-part-C.txt`
  - **Content**: `"well-done-youre-very-close"`
  - **Discovery Context**: Found during SSRF exploitation phase

- **flag4**:
  - **File**: `terraform/script/main.py` (line 24)
  - **Location**: Monitoring function response
  - **Content**: `"You found flag 4!"`
  - **Discovery Context**: Found through SSRF exploitation with metadata token parameter

### Module 4: IAM Privilege Escalation Flags
- **flag5**:
  - **File**: `terraform/challenge5.tf` (lines 35-36)
  - **Location**: IAM binding condition
  - **Content**: Title: `"flag5"`, Description: `"You found flag5!"`
  - **Discovery Context**: Found during IAM privilege escalation

- **flag3-attack-me**: Status TODO - planned for instance naming in privilege escalation scenario

## Implementation Patterns

### Deployment Strategy
- **Setup Scripts**: Flag files created during `mod1-setup.sh` and `mod2-setup.sh` execution
- **Terraform Resources**: Static bucket objects created via `google_storage_bucket_object`
- **VM Files**: Deployed via SCP using leaked SSH keys (maintains attack realism)
- **Bucket Files**: Uploaded via `gsutil cp` and `gcloud storage cp`

### Infrastructure Integration
- **No Breaking Changes**: All additions preserve existing resource dependencies
- **Automatic Cleanup**: Bucket objects deleted during `terraform destroy` via `force_destroy = true`
- **Authentication Patterns**: Uses existing service accounts and SSH key infrastructure
- **Error Handling**: Follows existing script patterns for robust deployment

## Educational Value Enhancement

### Progressive Discovery Design
- **Module 1**: Simple bucket enumeration → credential discovery → flag reward
- **Module 2**: State file exposure → SSH key extraction → multi-location flag hunt  
- **Module 3**: SSRF exploitation → metadata access → monitoring function flag discovery
- **Module 4**: IAM privilege escalation → service account impersonation → conditional role flag discovery

### Portal Integration Alignment
- **Flag Values**: Match exactly what CloudAI portal expects for module unlocking
- **Environment Variables**: Terraform variables flow through to portal configuration
- **Validation Scripts**: Existing `validate-m*.sh` scripts can verify flag presence

## Operational Considerations

### Deployment Reliability
- **Idempotent Operations**: Scripts handle re-runs without duplication
- **Dependency Management**: Flags deployed after infrastructure is stable
- **Cross-Module Consistency**: Uses shared temporary_files/ directory pattern

### Scalability for Multiple Sessions
- **Project-Scoped Resources**: All buckets and instances include `{project_id}` suffix
- **Variable Overrides**: Flag values configurable via `TF_VAR_` environment variables
- **Isolation**: Each deployment operates in separate GCP project scope

### Future Engineering Considerations
- **Flag Randomization**: Variable system supports unique flags per workshop instance
- **Content Expansion**: Template ready for additional hint files and challenge materials
- **Monitoring Integration**: Flag discovery events could feed into workshop analytics
- **Attack Path Validation**: Automated testing can verify flag accessibility via intended exploitation routes

## Files Modified
```
terraform/variables.tf        - Updated flag variable defaults
mod1-setup.sh                - Added Module 1 flags (lines 26-28, 59-60)
mod2-setup.sh                - Added Module 2 flag creation (lines 24-26, 31-32)
terraform/module3.tf          - Added Module 3 flag bucket object (lines 38-42)
terraform/script/main.py      - Added Module 3 monitoring function flag (line 24)
terraform/challenge5.tf       - Added Module 4 IAM condition flags (lines 35-36)
```

## Validation Strategy
- **Module Scripts**: Existing validation scripts can verify flag file presence
- **Portal Testing**: Flag submission through CloudAI portal interface
- **End-to-End**: Complete workshop flow validates all discovery paths
- **Playwright Tests**: Automated browser testing can verify UI flag submission

This implementation transforms the workshop from a purely educational exercise into an engaging CTF-style challenge while maintaining all defensive security learning objectives.
