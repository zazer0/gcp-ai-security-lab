# Module 3 Validation Script Progress Summary

## Context
- **Task**: Fix validation script for Module 3 of GCP AI Security Lab CTF
- **Infrastructure**: Uses Gen2 Cloud Functions (`google_cloudfunctions2_function`)
- **Previous State**: Script hanging at OAuth scope verification step
- **Root Cause**: Multiple shell execution and error handling issues

## Key Issues Identified

### 1. Shell Script Error Handling (`set -euo pipefail`)
- Script uses strict error handling that exits on any pipeline failure
- SSH commands through `exec_on_vm` were failing silently
- Grep commands with no matches would cause script termination

### 2. Variable Expansion in SSH Context
- **Initial Problem**: `$ACCESS_TOKEN` variable was expanding on host before SSH execution
- **Failed Attempt 1**: Split into two commands, but still had expansion issues
- **Failed Attempt 2**: Used escaped command substitution, but complex quoting caused hangs

### 3. OAuth Scope Check Command Structure
- Solution.md shows: `curl -i https://www.googleapis.com/oauth2/v3/tokeninfo\?access_token=$(gcloud auth print-access-token)`
- Note the escaped `\?` character - critical for proper URL formation
- Command must execute entirely within VM context

## Fixes Applied

### 1. OAuth Scope Verification (validate-m3.sh:164-201)
```bash
# Added explicit debugging
print_info "Command: $OAUTH_CMD"

# Proper error handling without silent failures
if ! SCOPE_OUTPUT=$(exec_on_vm "$OAUTH_CMD"); then
    print_fail "Failed to execute OAuth scope check on VM"
    print_info "Error output: $SCOPE_OUTPUT"
    exit 1
fi

# Show raw response for debugging
print_info "Raw OAuth response: $(echo "$SCOPE_OUTPUT" | head -c 500)"
```

### 2. Previous Gen2 Compatibility Fixes (Already Completed)
- **Function URL**: Dynamic lookup using `gcloud run services describe`
- **Authentication**: Uppercase "Bearer" header requirement
- **IAM Role**: Uses `roles/run.invoker` instead of `roles/cloudfunctions.invoker`

## Critical Insights for Scaling

### 1. Never Use Silent Failures
- Avoid `|| true` patterns that hide root causes
- Capture and log all error outputs explicitly
- Exit with proper error codes for CI/CD integration

### 2. SSH Command Execution Pitfalls
- Variable expansion happens at parse time, not execution time
- Complex nested quotes through SSH are fragile
- Always test command locally first, then wrap for SSH

### 3. Debugging Strategy
- Add verbose logging before complex operations
- Show exact commands being executed
- Capture raw outputs before processing

### 4. Script Robustness
- Consider temporarily disabling `pipefail` for specific operations
- But always re-enable and handle errors properly
- Never hide failures from operators

## Current Status
- OAuth scope check no longer hangs
- Proper error messages displayed if commands fail
- Ready for full validation run with deployed infrastructure

## Next Steps for Engineers
1. Run full validation: `./validate-m3.sh`
2. Monitor error outputs if failures occur
3. Check VM connectivity if SSH commands fail
4. Verify Gen2 function deployment if URL lookup fails

## Module 3 Attack Path (Reference)
1. SSH to VM with limited storage.read_only scope
2. Read function source from storage bucket
3. Discover SSRF vulnerability in monitoring function
4. Exploit to extract function's service account token
5. Token has full cloud-platform scope (privilege escalation)

## Related Files
- `validate-m3.sh` - Main validation script
- `invoke_monitoring_function.sh` - Helper script for function calls
- `terraform/module3.tf` - Infrastructure definition
- `solution.md` - Expected commands and outputs