# Module 1 Access Control Implementation

## Problem Statement
- Students initially had full GCP project access when starting the workshop
- This allowed direct access to the prod bucket, bypassing the intended privilege escalation learning path
- Module 1 requires students to discover service account credentials in dev bucket to progress

## Solution Overview
Implemented a limited-permission student service account that restricts initial access to only the dev bucket, forcing students to follow the intended learning path.

## Technical Implementation

### 1. Terraform Configuration (`terraform/module1.tf`)
- **Added `student-workshop` service account** (lines 45-50)
  - Account ID: `student-workshop`
  - Purpose: Limited initial access for workshop students
  
- **Granted minimal permissions** (lines 52-57)
  - Role: `roles/storage.objectViewer` 
  - Scope: ONLY `modeldata-dev` bucket
  - No access to `modeldata-prod` bucket
  
- **Created service account key** (lines 59-62)
  - Auto-generated for authentication
  
- **Added outputs for setup script** (lines 76-87)
  - `student_workshop_key`: Base64 encoded private key
  - `student_workshop_email`: Service account email

### 2. Setup Script (`challenge-setup.sh`)
- **Added account switching logic** (lines 160-197)
  - Executes after all infrastructure deployment
  - Backs up current admin config as `admin-backup`
  - Extracts student-workshop credentials from terraform output
  - Creates new gcloud configuration `student-workshop`
  - Activates student account with limited permissions
  
- **User messaging**
  - Clear indication of LIMITED permissions
  - Instructions to find bucket-service-account in dev bucket
  - Reference to switching back to admin if needed

### 3. Destroy Script (`challenge-destroy.sh`)
- **Added account restoration logic** (lines 544-574)
  - Executes before any cleanup operations
  - Checks for existence of `student-workshop` configuration
  - Switches back to `admin-backup` configuration
  - Deletes student-workshop configuration
  - Ensures admin permissions for resource cleanup

## Learning Path Flow

1. **Initial State**: Student starts with `student-workshop` account
   - Can list and read objects in `modeldata-dev` bucket
   - Cannot access `modeldata-prod` bucket

2. **Discovery Phase**: Student explores dev bucket
   - Finds `bucket-service-account.json` credentials
   - Learns to authenticate with discovered credentials

3. **Privilege Escalation**: Using found credentials
   - `bucket-service-account` has access to both dev and prod buckets
   - Student can now access prod bucket and find the flag

## Validation Script Updates Required

### Module 1 Validation (`validate-m1.sh`)
The validation script will need updates to account for the new access control:

1. **Pre-remediation checks**:
   - Verify student-workshop account is active
   - Confirm limited access (dev bucket only)
   - Check that bucket-service-account.json exists in dev bucket

2. **Post-remediation checks**:
   - Verify service account JSON has been removed from dev bucket
   - Confirm new service account created with proper role
   - Validate IAM bindings are correctly configured

3. **Testing considerations**:
   - Script may need to temporarily switch between accounts
   - Should verify both attack and defense paths work correctly
   - May need to use impersonation or saved credentials

## Key Insights

- **Security by Default**: Students start with minimal permissions, must work to escalate
- **Realistic Scenario**: Mimics real-world credential discovery attacks
- **Clear Learning Path**: Forces understanding of GCP IAM and service accounts
- **Reversible Changes**: Clean switching between student and admin contexts

## Future Improvements

- Consider adding more granular custom roles for different workshop stages
- Implement time-based access controls for workshop duration
- Add logging/monitoring of student actions for instructor visibility
- Create automated validation that works with the new permission model

## Testing Checklist

- [ ] Verify student can only access dev bucket initially
- [ ] Confirm bucket-service-account.json is discoverable
- [ ] Test privilege escalation path works as intended
- [ ] Validate cleanup properly restores admin access
- [ ] Ensure all subsequent modules still function correctly