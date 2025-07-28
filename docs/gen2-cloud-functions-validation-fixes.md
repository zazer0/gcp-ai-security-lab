# Gen2 Cloud Functions Validation Script Fixes

## Overview

This document provides comprehensive guidance for fixing the Module 3 validation script issues related to Google Cloud Functions Gen2 (2nd generation). The validation script currently uses Gen1 URL patterns and authentication methods, which are incompatible with Gen2 functions deployed using `google_cloudfunctions2_function` in Terraform.

## Gen1 vs Gen2 Architecture Differences

### Key Architectural Changes

1. **Infrastructure**: Gen2 functions are built on Cloud Run and Eventarc, while Gen1 functions use the original Cloud Functions infrastructure
2. **URL Format**: 
   - Gen1: `https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME`
   - Gen2: `https://FUNCTION_NAME-HASH-REGION.a.run.app` (Cloud Run service URL)
3. **IAM**: Gen2 uses Cloud Run IAM roles (`roles/run.invoker`) instead of Cloud Functions roles
4. **Terraform Resource**: `google_cloudfunctions2_function` vs `google_cloudfunctions_function`

### Performance and Features

Gen2 functions offer:
- Better performance through Cloud Run's container-based architecture
- Improved configuration flexibility (memory, CPU, concurrency)
- Enhanced monitoring and logging
- Support for traffic splitting and gradual rollouts
- Longer request timeout (up to 60 minutes vs 9 minutes)

## Retrieving Gen2 Function URLs

### Using gcloud CLI

```bash
# Get the service URL for a Gen2 function
FUNCTION_URL=$(gcloud run services describe FUNCTION_NAME \
  --region=REGION \
  --format='value(status.url)')

# Alternative using functions describe
FUNCTION_URL=$(gcloud functions describe FUNCTION_NAME \
  --gen2 \
  --region=REGION \
  --format='value(serviceConfig.uri)')
```

### In Terraform

To output the Gen2 function URL from Terraform:

```hcl
resource "google_cloudfunctions2_function" "function" {
  name     = "monitoring-function"
  location = var.region
  # ... other configuration
}

output "function_url" {
  value = google_cloudfunctions2_function.function.service_config[0].uri
}
```

### In Validation Script

Replace the hardcoded Gen1 URL construction:

```bash
# OLD (Gen1)
FUNCTION_URL="https://$LOCATION-$PROJECT_ID.cloudfunctions.net/monitoring-function"

# NEW (Gen2)
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)')
```

## Authentication for Gen2 Functions

### Required IAM Role

Gen2 functions require the `roles/run.invoker` role (not `roles/cloudfunctions.invoker`). The Terraform configuration correctly uses `google_cloud_run_service_iam_member` for this.

### Authentication with curl

```bash
# Basic authentication with user identity
curl -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "token"}'

# With service account impersonation
curl -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token --impersonate-service-account=SA_EMAIL)" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "token"}'
```

### Important Notes

- Use `Bearer` (capital B) in the Authorization header
- The token must be an identity token, not an access token
- For production, specify an audience claim for security

## OAuth Scope Verification Best Practices

### Robust Scope Checking

The validation script's scope verification can be improved:

```bash
# Get token info
SCOPE_OUTPUT=$(exec_on_vm "curl -s 'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=\$(gcloud auth print-access-token)' 2>/dev/null" || true)

# Primary check with jq
if command -v jq >/dev/null 2>&1; then
    if echo "$SCOPE_OUTPUT" | jq -r '.scope' 2>/dev/null | grep -q "devstorage.read_only"; then
        print_pass "VM has expected devstorage.read_only scope"
    else
        # Fallback to string matching
        if echo "$SCOPE_OUTPUT" | grep -q "devstorage.read_only"; then
            print_pass "VM has expected devstorage.read_only scope"
        else
            print_fail "VM missing expected devstorage.read_only scope"
        fi
    fi
else
    # No jq available, use grep
    if echo "$SCOPE_OUTPUT" | grep -q "devstorage.read_only"; then
        print_pass "VM has expected devstorage.read_only scope"
    else
        print_fail "VM missing expected devstorage.read_only scope"
    fi
fi
```

### Error Handling

Always check for API errors:

```bash
if echo "$SCOPE_OUTPUT" | grep -q '"error"'; then
    print_fail "Token verification failed"
    ERROR_DESC=$(echo "$SCOPE_OUTPUT" | grep -o '"error_description":"[^"]*"' | cut -d'"' -f4)
    print_info "Error: $ERROR_DESC"
else
    # Process valid response
fi
```

## Specific Fixes for validate-m3.sh

### 1. Update Function URL Construction (Line 281)

```bash
# Replace this line:
FUNCTION_URL="https://$LOCATION-$PROJECT_ID.cloudfunctions.net/monitoring-function"

# With:
print_info "Retrieving Gen2 function URL..."
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)' 2>/dev/null)

if [ -z "$FUNCTION_URL" ]; then
    print_fail "Could not retrieve function URL. Ensure the function is deployed."
    exit 1
fi
print_info "Using function URL: $FUNCTION_URL"
```

### 2. Fix OAuth Scope Verification (Lines 167-176)

```bash
# More robust implementation
SCOPE_OUTPUT=$(exec_on_vm "curl -s 'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=\$(gcloud auth print-access-token)' 2>/dev/null" || true)

# Check if we got a valid response
if [ -z "$SCOPE_OUTPUT" ] || echo "$SCOPE_OUTPUT" | grep -q '"error"'; then
    print_fail "Failed to retrieve token information"
    print_info "Debug: $SCOPE_OUTPUT"
else
    # Try to extract scopes properly
    SCOPES=$(echo "$SCOPE_OUTPUT" | grep -o '"scope":"[^"]*"' | cut -d'"' -f4 || echo "$SCOPE_OUTPUT")
    
    if echo "$SCOPES" | grep -q "devstorage.read_only"; then
        print_pass "VM has expected devstorage.read_only scope"
        print_info "VM OAuth scopes: $SCOPES"
    else
        print_fail "VM missing expected devstorage.read_only scope"
        print_info "Found scopes: $SCOPES"
    fi
fi
```

### 3. Update invoke_monitoring_function.sh

```bash
#!/bin/bash

# Get the Gen2 function URL dynamically
FUNCTION_URL=$(gcloud run services describe monitoring-function \
  --region=$LOCATION \
  --format='value(status.url)' 2>/dev/null)

if [ -z "$FUNCTION_URL" ]; then
    echo "Error: Could not retrieve function URL"
    exit 1
fi

# Send request to monitoring function
FUNCTION_RESPONSE=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "email"}')

echo $FUNCTION_RESPONSE
```

### 4. Fix Authentication Header (Line 286)

```bash
# Update the SSRF command
SSRF_CMD="curl -s -X POST '$FUNCTION_URL' \\
-H 'Authorization: Bearer \$(gcloud auth print-identity-token)' \\
-H 'Content-Type: application/json' \\
-d '{\"metadata\": \"token\"}'"
```

## Migration Considerations

### No Direct Upgrade Path

- Cannot upgrade a Gen1 function to Gen2 with the same name
- Must deploy with a new name and migrate traffic
- Can run Gen1 and Gen2 functions side-by-side

### Deployment Changes

- Add `--gen2` flag when using gcloud
- Use `google_cloudfunctions2_function` in Terraform
- Enable Artifact Registry API (required for Gen2)

### Testing Recommendations

1. Deploy Gen2 function with a different name first
2. Test thoroughly with the validation script
3. Gradually migrate traffic
4. Delete Gen1 function once migration is complete
5. Optionally rename Gen2 function to match original name

## Debugging Tips

### Check Function Deployment

```bash
# Verify the function exists as a Cloud Run service
gcloud run services list --region=$LOCATION | grep monitoring-function

# Get detailed function information
gcloud functions describe monitoring-function --gen2 --region=$LOCATION
```

### Test Authentication

```bash
# Test with explicit project
gcloud auth print-identity-token --project=$PROJECT_ID

# Verify IAM permissions
gcloud run services get-iam-policy monitoring-function --region=$LOCATION
```

### Common Issues

1. **401 Unauthorized**: Check IAM roles and ensure using identity token (not access token)
2. **404 Not Found**: Verify function name and region, ensure using Gen2 URL format
3. **Missing scopes**: VM service account may need additional OAuth scopes
4. **Function not found**: Ensure function is deployed as Gen2, not Gen1

## Summary

The key changes needed for the validation script:

1. Replace hardcoded Gen1 URLs with dynamic Gen2 URL retrieval
2. Update authentication headers to use "Bearer" with identity tokens
3. Improve OAuth scope verification with better error handling
4. Update the invocation script to use Gen2 patterns
5. Add proper error handling for all API calls

These changes will ensure the validation script works correctly with Gen2 Cloud Functions while maintaining backward compatibility and providing clear error messages when issues occur.