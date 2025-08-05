# Comprehensive GCP Resource Cleanup Implementation Plan

    Root Cause

    The cloudai-portal function persists because:
    1. It's a Cloud Functions v2 that creates both function metadata AND a Cloud Run service
    2. Current script incorrectly tries to delete the Cloud Run service directly (lines 162-166)
    3. This leaves the function metadata orphaned, causing "already exists" errors on next setup

    Concrete Implementation Logic

    1. Create New Comprehensive Cleanup Function (Insert after line 175)

    # Comprehensive cleanup function that ensures ALL resources are deleted
    cleanup_all_gcp_resources_comprehensive() {
        echo "##########################################################"
        echo "> Performing COMPREHENSIVE GCP resource cleanup..."
        echo "##########################################################"

        # PHASE 1: Delete Cloud Functions v2 (must be before Cloud Run)
        echo "=== PHASE 1: Cleaning up ALL Cloud Functions v2 ==="

        # Explicitly delete cloudai-portal function
        for region in us-east1 us-central1 us-west1; do
            if gcloud functions describe cloudai-portal --region="$region" --project="$PROJECT_ID" &>/dev/null; then
                echo "  Found cloudai-portal in $region - deleting..."
                gcloud functions delete cloudai-portal \
                    --region="$region" --project="$PROJECT_ID" --quiet --force 2>/dev/null || true
            fi
        done

        # Explicitly delete monitoring-function
        for region in us-east1 us-central1 us-west1; do
            if gcloud functions describe monitoring-function --region="$region" --project="$PROJECT_ID" &>/dev/null; then
                echo "  Found monitoring-function in $region - deleting..."
                gcloud functions delete monitoring-function \
                    --region="$region" --project="$PROJECT_ID" --quiet --force 2>/dev/null || true
            fi
        done

        # Delete ALL remaining functions (any region, any state)
        for func in $(gcloud functions list --format="value(name)" --project="$PROJECT_ID" 2>/dev/null); do
            func_region=$(gcloud functions list --filter="name:$func" --format="value(location)" --project="$PROJECT_ID" 2>/dev/null)
            if [ ! -z "$func_region" ]; then
                echo "  Deleting function $func in region $func_region..."
                gcloud functions delete "$func" \
                    --region="$func_region" --project="$PROJECT_ID" --quiet --force 2>/dev/null || true
            fi
        done

        # PHASE 2: Delete orphaned Cloud Run services (AFTER functions)
        echo "=== PHASE 2: Cleaning up orphaned Cloud Run services ==="
        for service in $(gcloud run services list --format="value(name)" --project="$PROJECT_ID" 2>/dev/null); do
            service_region=$(gcloud run services list --filter="name:$service" --format="value(region)" --project="$PROJECT_ID"
    2>/dev/null)
            if [ ! -z "$service_region" ]; then
                echo "  Deleting Cloud Run service $service in region $service_region..."
                gcloud run services delete "$service" \
                    --region="$service_region" --project="$PROJECT_ID" --quiet 2>/dev/null || true
            fi
        done

        # PHASE 3: Delete compute instances
        echo "=== PHASE 3: Cleaning up compute instances ==="
        for instance in $(gcloud compute instances list --format="value(name)" --project="$PROJECT_ID" 2>/dev/null); do
            zone=$(gcloud compute instances list --filter="name:$instance" --format="value(zone)" --project="$PROJECT_ID" 2>/dev/null)
            if [ ! -z "$zone" ]; then
                echo "  Deleting instance $instance in zone $zone..."
                gcloud compute instances delete "$instance" \
                    --zone="$zone" --project="$PROJECT_ID" --quiet 2>/dev/null || true
            fi
        done

        # PHASE 4: Delete ALL storage buckets
        echo "=== PHASE 4: Cleaning up ALL storage buckets ==="
        for bucket in $(gcloud storage buckets list --format="value(name)" --project="$PROJECT_ID" 2>/dev/null | grep -E
    "modeldata-|file-uploads-|cloud-function-bucket-" || true); do
            echo "  Deleting bucket gs://$bucket..."
            gcloud storage rm -r "gs://$bucket/" --project="$PROJECT_ID" 2>/dev/null || true
        done

        # PHASE 5: Delete ALL secrets
        echo "=== PHASE 5: Cleaning up secrets ==="
        for secret in $(gcloud secrets list --format="value(name)" --project="$PROJECT_ID" 2>/dev/null | grep -E "ssh-key|" || true);
    do
            echo "  Deleting secret $secret..."
            gcloud secrets delete "$secret" --project="$PROJECT_ID" --quiet 2>/dev/null || true
        done

        # PHASE 6: Delete service accounts
        echo "=== PHASE 6: Cleaning up service accounts ==="
        for sa in bucket-service-account monitoring-function terraform-pipeline cloudai-portal; do
            if gcloud iam service-accounts describe "$sa@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
                echo "  Deleting service account $sa..."
                gcloud iam service-accounts delete \
                    "$sa@$PROJECT_ID.iam.gserviceaccount.com" \
                    --project="$PROJECT_ID" --quiet 2>/dev/null || true
            fi
        done

        # PHASE 7: Delete custom IAM roles
        echo "=== PHASE 7: Cleaning up custom IAM roles ==="
        for role in DevBucketAccess TerraformPipelineProjectAdmin; do
            if gcloud iam roles describe "$role" --project="$PROJECT_ID" &>/dev/null; then
                echo "  Deleting custom role $role..."
                gcloud iam roles delete "$role" --project="$PROJECT_ID" --quiet 2>/dev/null || true
            fi
        done

        # PHASE 8: Clean up IAM policy bindings
        echo "=== PHASE 8: Cleaning up IAM bindings ==="
        # Remove specific bindings for deleted service accounts
        for sa in bucket-service-account monitoring-function terraform-pipeline; do
            member="serviceAccount:$sa@$PROJECT_ID.iam.gserviceaccount.com"
            # Get all roles for this member
            roles=$(gcloud projects get-iam-policy "$PROJECT_ID" --format="json" | \
                jq -r ".bindings[] | select(.members[] | contains(\"$member\")) | .role" 2>/dev/null || true)
            for role in $roles; do
                echo "  Removing $member from role $role..."
                gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
                    --member="$member" --role="$role" 2>/dev/null || true
            done
        done

        echo "Comprehensive cleanup complete!"
    }

    2. Remove Incorrect Cleanup Logic (Delete/Comment lines 161-174)

    Remove the incorrect Cloud Run service deletion for cloudai-portal:
    # DELETE THESE LINES (161-174):
        # Delete CloudAI portal resources
        if gcloud run services describe cloudai-portal --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
            echo "  Deleting Cloud Run service cloudai-portal..."
            gcloud run services delete cloudai-portal \
                --region="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null || true
        fi

        # Delete CloudAI portal service account
        if gcloud iam service-accounts describe "cloudai-portal@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
            echo "  Deleting service account cloudai-portal..."
            gcloud iam service-accounts delete \
                "cloudai-portal@$PROJECT_ID.iam.gserviceaccount.com" \
                --project="$PROJECT_ID" --quiet 2>/dev/null || true
        fi

    3. Update Main Execution Flow (Replace lines 510-516)

    # Always run comprehensive cleanup to catch everything
    echo ""
    echo "##########################################################"
    echo "> Running comprehensive cleanup to ensure nothing remains..."
    echo "##########################################################"
    cleanup_all_gcp_resources_comprehensive

    # Then run the original cleanup as backup
    echo ""
    echo "##########################################################"
    echo "> Running legacy cleanup as final verification..."
    echo "##########################################################"
    cleanup_gcp_resources

    4. Add Pre-Destroy Verification (Insert after line 441)

    # Verify no cloudai-portal exists before attempting terraform
    echo "##########################################################"
    echo "> Pre-destroy verification for known problematic resources..."
    echo "##########################################################"

    # Check for cloudai-portal function specifically
    for region in us-east1 us-central1 us-west1; do
        if gcloud functions describe cloudai-portal --region="$region" --project="$PROJECT_ID" &>/dev/null; then
            echo "WARNING: Found existing cloudai-portal in $region - will force delete"
            gcloud functions delete cloudai-portal \
                --region="$region" --project="$PROJECT_ID" --quiet --force 2>/dev/null || true
        fi
    done

    5. Update Import Function (Modify lines 282-291)

    # Don't try to import cloudai-portal if it's in UNKNOWN state
    if gcloud functions describe cloudai-portal --region="$REGION" &>/dev/null; then
        func_state=$(gcloud functions describe cloudai-portal --region="$REGION" --format="value(state)" 2>/dev/null)
        if [ "$func_state" != "UNKNOWN" ] && [ "$func_state" != "ERROR" ]; then
            echo "  Attempting to import cloudai-portal function..."
            terraform import \
                -var="project_id=$PROJECT_ID" \
                -var="project_number=$PROJECT_NUMBER" \
                google_cloudfunctions2_function.cloudai_portal \
                "projects/$PROJECT_ID/locations/$REGION/functions/cloudai-portal" \
                2>/dev/null || echo "    Import failed, will force delete"
        else
            echo "  cloudai-portal is in $func_state state - skipping import, will force delete"
        fi
    fi

    Key Changes Summary:

    1. Comprehensive cleanup function that deletes ALL resources in correct order
    2. Phase-based deletion: Functions → Cloud Run → Compute → Storage → Secrets → Service Accounts → Roles → IAM
    3. Multi-region support for functions (not just us-east1)
    4. Force flag on all deletions to handle stuck resources
    5. Remove incorrect logic that deletes Cloud Run services for v2 functions
    6. Pre-destroy verification specifically for cloudai-portal
    7. Conditional imports that skip UNKNOWN/ERROR state resources

    This ensures:

    - Cloud Functions v2 are deleted properly (function deletes its Cloud Run service)
    - No orphaned resources remain in any region
    - Resources in bad states are force-deleted
    - Complete cleanup even if terraform state is corrupted
