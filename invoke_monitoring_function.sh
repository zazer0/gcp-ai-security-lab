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