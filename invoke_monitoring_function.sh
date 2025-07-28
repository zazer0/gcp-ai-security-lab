#!/bin/bash

# Hard-code the Gen2 function URL to avoid OAuth scope issues
# The URL format for Gen2 Cloud Functions is: https://{function-name}-{hash}-{region-code}.a.run.app
# Since we can't dynamically get the hash, we'll use the one from the validation output
FUNCTION_URL="https://monitoring-function-rr4orxndwa-ue.a.run.app"

# Send request - request 'token' instead of 'email' to get the access token
FUNCTION_RESPONSE=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "token"}')

echo $FUNCTION_RESPONSE