# Engineering Pitfalls & Solutions Synthesis
_Consolidated learnings from GCP AI Security Lab workshop development_

## Executive Summary: Critical Failures to Avoid

### 🚨 Top 3 Anti-Patterns That Will Break Everything
1. **Silent Failures**: `|| true`, `2>/dev/null`, `--quiet` masks critical errors
2. **Unhandled `set -e`**: Script exits early, skipping cleanup functions
3. **State Desynchronization**: Multiple terraform directories without proper import logic

### ⚡ Quick Wins
- Run `bash -n script.sh` after ANY script modification
- Never add backslashes after final terraform import arguments
- Always include new resources in ALL cleanup locations (usually 3+)
- Import existing resources before terraform apply to prevent 409 errors

---

## Core Issues & Resolutions

### 1. Shell Script Error Handling

#### Problem Pattern
```bash
# DON'T DO THIS - Silent failures cascade
gcloud iam service-accounts delete "$SA" --quiet || true
terraform import ... 2>/dev/null
cd terraform  # With set -e, fails in worktree → script exits
```

#### Solution Pattern
```bash
# DO THIS - Explicit error handling
if ! gcloud iam service-accounts delete "$SA"; then
    echo "ERROR: Failed to delete $SA"
    exit 1  # Critical operations
fi

# For non-critical operations
if ! gcloud projects remove-iam-policy-binding ...; then
    echo "WARNING: IAM binding removal failed (may already be removed)"
fi

# Directory changes with validation
if [ -d terraform ]; then
    cd terraform
else
    echo "WARNING: terraform directory not found, skipping"
fi
```

#### Key Insight
- **12 instances of `|| true`** removed from setup script
- **Result**: Fail-fast behavior exposed 409 "already exists" root cause
- **Lesson**: Visibility over silence - see failures to fix them

### 2. Terraform State Management Complexity

#### Architecture Reality
```
terraform_module1/     → Creates resources, own state file
terraform/module1.tf   → References same resources, different state
challenge-setup.sh     → Must import Module1 resources to main state
challenge-destroy.sh   → Must remove from main state before module1 destroy
```

#### Import Logic Requirements
```bash
# Setup: Check existence → Import if exists → Apply
if gcloud iam service-accounts describe "student-workshop@$PROJECT_ID..." &>/dev/null; then
    terraform import \
        -var="project_id=$PROJECT_ID" \
        -var="project_number=$PROJECT_NUMBER" \
        google_service_account.student-workshop \
        "projects/$PROJECT_ID/serviceAccounts/student-workshop@$PROJECT_ID..."
fi
```

#### Critical Ordering
1. **Setup**: Module1 terraform → Import to main → Main terraform
2. **Destroy**: Remove from main state → Destroy module1 → Destroy main → Manual cleanup

### 3. Resource Cleanup Architecture

#### The Triple Redundancy Problem (Before)
- EXIT trap calling cleanup (lines 12-34)
- Direct call to `cleanup_all_gcp_resources_comprehensive()` (line 804)
- Second call to `cleanup_gcp_resources()` (line 811)
- **Result**: Same resources deleted 3x, script 40% slower

#### Streamlined Solution (After)
```bash
# Single cleanup flow with phases
cleanup_all_gcp_resources() {
    # Phase 1: Cloud Functions (must be before Cloud Run)
    # Phase 2: Cloud Run services
    # Phase 3: Compute instances
    # Phase 4: Storage buckets
    # Phase 5: Secrets
    # Phase 6: Service accounts (after IAM bindings)
    # Phase 7: Custom IAM roles
    # Phase 8: IAM policy bindings
}
```

#### Resource Addition Checklist
When adding new resource (e.g., `student-workshop` SA):
- [ ] Add to terraform configuration
- [ ] Add to direct cleanup section
- [ ] Add to comprehensive cleanup phases
- [ ] Add to IAM binding cleanup
- [ ] Add import logic to setup script
- [ ] Test full cycle: setup → destroy → setup

### 4. Service Account Lifecycle Management

#### The Student-Workshop Problem
```
Created: terraform_module1 → Used: gcloud config → Problem: Persists after destroy
```

#### Auth Contamination Fix
```bash
# Before cleanup operations
current_config=$(gcloud config get-value account 2>/dev/null)
if [[ "$current_config" == *"student-workshop"* ]]; then
    gcloud config configurations activate default
    gcloud auth activate-service-account "$ADMIN_ACCOUNT" --key-file="$KEY_FILE"
fi
```

---

## Key Technical Pitfalls

### Syntax Trap: Backslash Continuations
```bash
# WRONG - Backslash consumes 'fi'
terraform import \
    google_service_account.foo \
    "projects/.../foo" \
fi  # Interpreted as terraform argument!

# RIGHT - No trailing backslash
terraform import \
    google_service_account.foo \
    "projects/.../foo"
fi
```

### Import Visibility Trade-off
```bash
# Old: Hidden failures
terraform import ... 2>/dev/null || true

# New: Visible for debugging
terraform import ...
# Shows "Resource already exists" - can now optimize
```

### Cleanup Order Dependencies
1. **Functions before Cloud Run** (v2 functions are Cloud Run services)
2. **IAM bindings before Service Accounts** (can't delete SA with active bindings)
3. **Terraform state removal before destroy** (avoid state conflicts)
4. **Force delete UNKNOWN state resources first**

---

## Architectural Insights

### Module Interdependencies
```
Module 1: Creates base resources (buckets, student SA)
    ↓ imports
Main Terraform: References Module 1 resources + adds more
    ↓ setup creates
Module 2: Separate VM infrastructure
    ↓ all feed into
Module 3-4: Advanced challenges using all resources
```

### State Synchronization Points
1. **After Module1 creation**: Import to main state
2. **Before destroy**: Remove Module1 resources from main state
3. **On re-setup**: Check & import orphaned resources

### Error Propagation Paths
```
student-workshop exists → Module1 apply fails → Setup crashes
    ↓
Destroy has set -e → cd fails in worktree → Cleanup skipped
    ↓
Resources persist → Next setup fails with 409
```

---

## Best Practices Checklist

### Script Development
- [ ] Run `bash -n` syntax check after modifications
- [ ] Replace `|| true` with explicit error handling
- [ ] Check directory existence before `cd` operations
- [ ] Validate extracted variables (PROJECT_NUMBER, ZONE, etc.)
- [ ] Show progress - remove `--quiet` flags

### Terraform Operations
- [ ] Check resource existence before terraform apply
- [ ] Import orphaned resources proactively
- [ ] Handle multiple state files explicitly
- [ ] Document import requirements in comments

### Cleanup Scripts
- [ ] No `set -e` in cleanup/destroy scripts
- [ ] Make cleanup idempotent (handle missing resources)
- [ ] Order cleanup by dependencies
- [ ] Include ALL resources in ALL cleanup locations
- [ ] Test cleanup with partially deployed infrastructure

### Testing Procedures
- [ ] Full cycle test: setup → destroy → setup
- [ ] Verify no orphaned resources: `gcloud iam service-accounts list`
- [ ] Check IAM bindings: `gcloud projects get-iam-policy $PROJECT_ID`
- [ ] Validate auth state: `gcloud config get-value account`

---

## Validation Commands

### Pre-Setup Checks
```bash
# Check for orphaned service accounts
gcloud iam service-accounts list --filter="email:student-workshop@*"
gcloud iam service-accounts list --filter="email:bucket-service-account@*"

# Verify clean IAM state
gcloud projects get-iam-policy $PROJECT_ID --format=json | grep -E "(student-workshop|bucket-service)"
```

### Post-Destroy Verification
```bash
# Ensure complete cleanup
for resource in student-workshop bucket-service-account monitoring-function; do
    echo "Checking $resource..."
    gcloud iam service-accounts describe "$resource@$PROJECT_ID.iam.gserviceaccount.com" 2>&1 | grep -q "NOT_FOUND" && echo "✓ Deleted" || echo "✗ Still exists"
done

# Verify terraform state
cd terraform && terraform state list | grep -E "module1" && echo "WARNING: Module1 resources in main state"
```

### Script Validation
```bash
# Syntax check
bash -n challenge-setup.sh && echo "✓ Setup syntax valid"
bash -n challenge-destroy.sh && echo "✓ Destroy syntax valid"

# Execution test (dry-run concept)
bash -x challenge-setup.sh 2>&1 | head -50  # See execution flow
```

---

## Future Improvements Priority

### High Priority (Prevents Failures)
1. Add `--dry-run` flag to preview operations
2. Implement resource existence checks before all operations
3. Create centralized resource list variable
4. Add retry logic for transient API failures

### Medium Priority (Improves Experience)
5. Parallelize independent operations
6. Add progress percentage indicators
7. Generate cleanup summary report
8. Implement rollback on partial failure

### Low Priority (Nice to Have)
9. Extract resource lists to configuration file
10. Add terraform/gcloud version checking
11. Create resource tagging strategy
12. Build automated testing harness

---

## Summary: Never Forget

1. **Silent failures (`|| true`) hide root causes** - removed 12 instances, immediately found real issue
2. **`set -e` + missing directory = skipped cleanup** - why student-workshop persisted
3. **Multiple terraform directories need explicit state management** - import or fail
4. **Backslash continuations break control flow** - 4 unclosed if statements from one character
5. **New resources need 3+ cleanup locations** - direct, comprehensive, IAM bindings
6. **Auth contamination persists across runs** - must switch away from student config
7. **Cleanup order matters** - functions→compute→storage→secrets→SAs→IAM

**The Meta Lesson**: Visibility and explicit error handling prevent 90% of scaling issues. When something fails, it should fail loudly with context, not silently cascade into mysterious problems three steps later.