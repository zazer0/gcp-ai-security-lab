# Gen2 Cloud Functions Validation Script Fixes

## Problem Summary
The Module 3 validation script fails because it uses Gen1 Cloud Functions URL patterns and authentication, but the infrastructure uses Gen2 functions (`google_cloudfunctions2_function`).

## Required Code Changes

### 1. Fix Function URL (validate-m3.sh, line 281)
```bash
# REMOVE:
FUNCTION_URL="https://$LOCATION-$PROJECT_ID.cloudfunctions.net/monitoring-function"

# REPLACE WITH:
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)')
```

### 2. Fix Authentication Header (validate-m3.sh, line 286)
```bash
# CHANGE: bearer → Bearer
-H 'Authorization: Bearer $(gcloud auth print-identity-token)'
```

### 3. Fix OAuth Scope Check (validate-m3.sh, lines 167-176)
```bash
# REPLACE the scope check with:
SCOPE_OUTPUT=$(exec_on_vm "curl -s 'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=\$(gcloud auth print-access-token)' 2>/dev/null" || true)

# Extract scopes more reliably
SCOPES=$(echo "$SCOPE_OUTPUT" | grep -o '"scope":"[^"]*"' | cut -d'"' -f4)

if echo "$SCOPES" | grep -q "devstorage.read_only"; then
    print_pass "VM has expected devstorage.read_only scope"
else
    # Fallback check
    if echo "$SCOPE_OUTPUT" | grep -q "devstorage.read_only"; then
        print_pass "VM has expected devstorage.read_only scope"
    else
        print_fail "VM missing expected devstorage.read_only scope"
    fi
fi
```

### 4. Update invoke_monitoring_function.sh
```bash
#!/bin/bash

# Get Gen2 function URL dynamically
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)')

# Send request
FUNCTION_RESPONSE=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "email"}')

echo $FUNCTION_RESPONSE
```

## Key Differences: Gen1 vs Gen2

| Aspect | Gen1 | Gen2 |
|--------|------|------|
| URL Format | `https://REGION-PROJECT.cloudfunctions.net/NAME` | `https://NAME-HASH-REGION.a.run.app` |
| IAM Role | `roles/cloudfunctions.invoker` | `roles/run.invoker` |
| Backend | Cloud Functions | Cloud Run |
| Terraform Resource | `google_cloudfunctions_function` | `google_cloudfunctions2_function` |

## Testing the Fix

After making changes:
```bash
# Verify function exists
gcloud run services list --region=$LOCATION | grep monitoring-function

# Test authentication
curl -X POST $(gcloud run services describe monitoring-function --region=$LOCATION --format='value(status.url)') \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "token"}'
```

All validation checks should pass after these changes.