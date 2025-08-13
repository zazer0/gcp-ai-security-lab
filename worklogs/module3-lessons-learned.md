# Module 3 Validation - Lessons Learned

## Executive Summary
Module 3 validation required complete refactoring to work within the authentic CTF exploit chain. This document consolidates critical lessons from implementing a permission-respecting validation framework that mirrors the actual student experience.

## Core Problem & Solution

### The Challenge
Module 3 validation initially used admin credentials, bypassing security boundaries and breaking exploit continuity from Modules 1-2.

### The Fix
Implemented authentic exploit chain: Module 1 (bucket discovery) → Module 2 (SSH extraction) → Module 3 (SSRF via SSH), using only permissions gained through exploitation.

## Critical Implementation Details

### 1. State Persistence Between Modules
**Problem**: Temporary directories prevented artifact sharing between modules.

**Solution**: Use persistent `./val-test` directory:
```
./val-test/
├── vm_ip.txt           # VM IP from Module 2
├── ssh_key             # SSH private key from terraform state
└── bucket-sa.json      # Service account from Module 1
```

### 2. Permission Boundary Respect
**Problem**: `bucket-service-account` lacks `run.services.get` permission for Cloud Functions.

**Solution**: Retrieve function URL from VM perspective:
- Primary: Read `/home/alice/.function_url` (deployed during setup)
- Fallback: Parse `invoke_monitoring_function.sh` output
- Never use `gcloud run services describe` in validation

### 3. SSH Access Without Admin Privileges
**Problem**: `gcloud compute ssh` requires `compute.instances.setMetadata` permission.

**Solution**: Use direct SSH with extracted key:
```bash
ssh -i "./val-test/ssh_key" -o StrictHostKeyChecking=no alice@$VM_IP
```

### 4. Infrastructure Immutability
**Problem**: Validation attempted to copy scripts already on VM.

**Solution**: Remove redundant operations (e.g., scp in lines 365-378). Test existing infrastructure deployed during setup.

## Key Design Principles

### Mirror Student Experience
- Validation uses exact same exploit path as workshop participants
- No shortcuts or admin privileges
- Each module builds on previous exploits

### Respect Intentional Boundaries
- Permission denials are security features, not bugs
- VM has different perspective than external validation
- Work within constraints, don't bypass them

### Test, Don't Deploy
- Infrastructure setup happens in `challenge-setup.sh`
- Validation only tests what exists
- Root-owned files prevent tampering

## Technical Changes Summary

| File | Key Changes | Purpose |
|------|------------|---------|
| validate-m2.sh | Use persistent `./val-test` directory | Enable state sharing |
| validate-m3.sh | Remove 102 lines of config switching | Respect permissions |
| validate-m3.sh | Get function URL from VM, not API | Work within boundaries |
| validate-m3.sh | Remove scp operation (lines 365-378) | Test existing infrastructure |
| validate-driver.sh | Add Module 3 orchestration | Complete exploit chain |

## Common Pitfalls to Avoid

1. **Don't use admin credentials** - Always use exploited permissions only
2. **Don't assume Cloud Run access** - bucket-SA intentionally lacks these
3. **Don't recreate existing files** - Test infrastructure deployed during setup
4. **Don't use pipefail or || true** - Follow shell scripting best practices
5. **Don't cleanup shared state prematurely** - Let driver manage lifecycle

## Validation Results

Module 3 now passes all 27 checks:
- SSH access verification using Module 2's key
- Function URL retrieval from VM perspective
- SSRF exploitation via monitoring function
- Metadata endpoint access testing
- Privilege escalation path validation

## Future Improvements

- Extend state-sharing pattern to Module 4
- Consider environment variable for val-test location
- Add explicit symlink integrity checks
- Template monitoring script with dynamic values

## Key Takeaway

**Successful CTF validation requires thinking like an attacker** - use only what you've exploited, work within constraints, and maintain authenticity. The validation framework now properly demonstrates both successful attacks and effective remediations while respecting all intentional security boundaries.