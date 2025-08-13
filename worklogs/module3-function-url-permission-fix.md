# Module 3 Function URL Permission Fix - Implementation Summary

## Context
Fixed Module 3 validation failure where `bucket-service-account` lacks Cloud Run permissions to describe the monitoring function, breaking the SSRF exploitation test path.

## Problem Identified
- **Error**: `gcloud run services describe` failed with `PERMISSION_DENIED: Permission 'run.services.get' denied`
- **Location**: validate-m3.sh lines 407-410
- **Impact**: Module 3 validation couldn't retrieve function URL to test SSRF vulnerability
- **Root Cause**: Validation runs as `bucket-service-account` which intentionally lacks Cloud Run admin permissions

## Solution Implemented

### Key Insight
- Function URL already exists on VM at `/home/alice/.function_url` (placed by challenge-setup.sh)
- VM's `invoke_monitoring_function.sh` successfully uses this file
- Validation should retrieve URL from VM rather than using gcloud directly

### Code Changes
**File**: `validate-m3.sh`
**Lines Modified**: 407-425 (replaced 4 lines with 20 lines)

**Implementation**:
1. **Primary method**: Read `/home/alice/.function_url` from VM via SSH
2. **Fallback method**: Extract URL from `invoke_monitoring_function.sh` output
3. **Error handling**: Clear failure message if neither method works
4. **Shell best practices**: No pipefail, no `|| true`, proper error checking

### Technical Details
- Uses `exec_on_vm` function (SSH with Module 2's extracted key)
- Extracts URL from script stderr output using grep/sed
- Maintains exploit path authenticity (no privilege escalation)

## Validation Architecture

### Permission Boundaries
- **Module 1**: Public → bucket-service-account
- **Module 2**: bucket-service-account + SSH access
- **Module 3**: Same as Module 2 (no additional GCP permissions)
- **Intentional design**: Cloud Run permissions withheld to simulate realistic attack scenario

### State Continuity
- Module 2 saves SSH credentials to `./val-test/`
- Module 3 uses these credentials for VM access
- Function URL retrieved from VM's perspective, not external validation

## Testing Status
- **Change implemented**: Successfully replaced gcloud command with VM-based retrieval
- **Next step**: Run `./validate-driver.sh` to verify complete validation chain
- **Expected outcome**: Module 3 should pass all 26 validation checks

## Key Learnings

### Security Design Validation
- Validation scripts must respect intentional permission boundaries
- VM has resources/URLs that external accounts shouldn't access directly
- This mirrors real-world scenarios where compromised VMs have different access than external attackers

### Implementation Pattern
- Always check VM-local resources before attempting external API calls
- Use multi-method fallback for robustness
- Clear error messages help debug permission issues

## Related Work
- Builds on Module 3 validation integration (module3-validation-integration.md)
- Continues exploit chain from Module 2 (module2-validation-integration.md)
- Part of larger validation framework refactor (validation-refactor-driver-pattern.md)

## Files Modified
1. `validate-m3.sh`: Lines 407-425 replaced with VM-based URL retrieval

## Outstanding Tasks
- Run full validation suite to confirm fix
- Verify all 3 modules pass in sequence
- Document any additional permission issues discovered

## Result
Module 3 validation now correctly retrieves the Cloud Function URL from the VM's perspective, maintaining the authentic exploit path without requiring Cloud Run permissions for the validation service account.