# Module 1 Student Service Account Implementation Summary

## Overview
Implemented a student-scoped service account system for Module 1 of the GCP AI Security Lab, providing workshop participants with limited initial permissions that force discovery of privilege escalation paths.

## Key Implementation Components

### 1. Service Account Architecture
- **student-workshop@**: Limited-permission account for workshop participants
  - Access: Read-only to modeldata-dev bucket only
  - Purpose: Initial entry point requiring credential discovery
- **bucket-service-account@**: Target account with broader permissions
  - Access: Read to both dev and prod buckets
  - Credentials deliberately leaked in dev bucket for discovery

### 2. Setup Script Modifications (`challenge-setup.sh`)
- **Lines 162-202**: Automatic gcloud configuration switching
  - Backs up admin configuration before switching
  - Creates student-workshop configuration
  - Activates student service account credentials
  - Provides clear feedback about permission limitations
- **Lines 59-122**: Resource import logic for idempotent runs
  - Imports existing Module 1 resources if present
  - Prevents "already exists" errors on repeated runs

### 3. Destroy Script Enhancements (`challenge-destroy.sh`)
- **Auth Corruption Prevention** (lines 585-628):
  - Revokes student-workshop credentials before deletion
  - Explicitly switches account (not just configuration)
  - Verifies successful switch before cleanup
  - Prevents SQLite cache corruption issues
- **Service Account Cleanup** (line 272):
  - Added student-workshop to deletion list
  - Ensures complete teardown

### 4. Module 1 Setup Script (`mod1-setup.sh`)
- Deploys bucket-service-account credentials to dev bucket
- Creates portal_info.txt with CloudAI Labs branding
- Sets up deliberate vulnerability chain

### 5. Validation Scripts
- **validate-m1.sh**: Tests student can't directly access prod
- **validate-m2.sh**: Verifies privilege escalation succeeded
- **validate-m3.sh**: Confirms remediation applied

## Critical Fixes Applied

### Service Account Persistence Issue
- **Problem**: student-workshop account persisted across destroy/setup cycles
- **Root Cause**: Missing from cleanup lists and import checks
- **Solution**: 
  - Added to destroy script deletion loops (lines 272, 293)
  - Added import check in setup script (after line 71)
  - Follows existing patterns for consistency

### Authentication State Corruption
- **Problem**: gcloud auth entered invalid state after config deletion
- **Root Cause**: Orphaned auth tokens and SQLite cache issues
- **Solution**: Implemented proper credential revocation before deletion
- **Details**: See `gcloud-auth-corruption-fix.md`

## User Experience Flow
1. **Initial State**: Students start with student-workshop account
2. **Discovery Phase**: Can only list/read modeldata-dev bucket
3. **Escalation**: Find bucket-service-account credentials in dev
4. **Achievement**: Use found credentials to access prod bucket
5. **Remediation**: Remove leaked credentials, implement proper IAM

## Testing Verification
- Setup → Destroy → Setup cycle works without errors
- Student account properly restricted to dev bucket only
- Bucket-service-account credentials successfully grant prod access
- Validation scripts accurately detect attack and remediation states
- No authentication corruption after destroy

## Architecture Benefits
- **Educational**: Clear privilege escalation learning path
- **Realistic**: Mimics real-world credential leakage scenarios
- **Safe**: Limited permissions prevent accidental damage
- **Automated**: Configuration switching removes manual steps
- **Recoverable**: Admin access preserved in backup config

## Integration Points
- Terraform Module 1 creates both service accounts
- CloudAI Portal displays initial limited access
- Validation scripts test the full attack chain
- Destroy script ensures clean state reset

## Future Considerations
- Consider adding more granular permissions for intermediate steps
- Could implement time-based credential rotation for added realism
- Potential for adding audit logging to track student progress
- Option to disable admin backup for competition scenarios

## Related Documentation
- `module1-implementation-summary.md`: Initial module design
- `gcloud-auth-corruption-fix.md`: Auth state management details
- `module1-ui-simplification-achievement.md`: Portal integration
- `module1-access-control-implementation.md`: IAM structure

## Commands for Manual Testing
```bash
# Check current account
gcloud config get-value account

# Switch to admin
gcloud config configurations activate admin-backup

# Switch to student
gcloud config configurations activate student-workshop

# Test access
gsutil ls gs://modeldata-dev-$PROJECT_ID/
gsutil ls gs://modeldata-prod-$PROJECT_ID/  # Should fail for student
```