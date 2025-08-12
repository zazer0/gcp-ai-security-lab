# Validation Script GCloud Configuration Fix

## Issue Identified
- **Script**: `validate-m3.sh` line 187
- **Error**: `ERROR: (gcloud.config.get-value) Section [core] has no property [configuration]`
- **Root Cause**: Invalid gcloud command attempting to retrieve current active configuration name

## Fix Applied
- **Original Command**: `gcloud config get-value configuration 2>"$ACCOUNT_STDERR"`
- **Corrected Command**: `gcloud config configurations list --filter="is_active=true" --format="value(name)"`
- **Key Change**: Removed stderr redirection per requirements (no abstraction of STDERR)

## Technical Details
- The `gcloud config get-value` command expects property names like `account`, `project`, not `configuration`
- Proper method to get active configuration requires querying the configurations list with active filter
- Used devops-shell-expert subagent for implementation per specified workflow

## Validation Results
- All 30 tests now pass successfully
- Configuration switching between `student-workshop` and `admin-backup` works correctly
- Module 3 infrastructure validation complete:
  - Student permissions properly restricted
  - Admin backup configuration accessible
  - SSRF vulnerability chain validated
  - Privilege escalation path confirmed

## Impact
- Enables proper testing of multi-configuration scenarios
- Critical for validating student vs admin permission boundaries
- Ensures Module 3 lab exercises function as designed

## Future Considerations
- Similar pattern may exist in other validation scripts
- Consider standardizing configuration checks across all modules
- Document gcloud configuration management patterns for team reference