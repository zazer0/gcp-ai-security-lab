#!/bin/bash

set -e  # Exit on error

# Function to check terraform state
check_terraform_state() {
    local dir=$1
    if [ -f "$dir/terraform.tfstate" ]; then
        local resource_count=$(terraform -chdir="$dir" state list 2>/dev/null | grep -c "google_" || echo "0")
        echo "Found $resource_count managed resources in $dir state"
        return 0
    fi
    echo "No state file found in $dir"
    return 1
}

# Function to clean up known resources directly via gcloud
cleanup_gcp_resources() {
    echo "##########################################################"
    echo "> Performing direct GCP resource cleanup..."
    echo "##########################################################"
    
    # Module 2 resources
    echo "Cleaning up Module 2 resources..."
    
    # Delete compute instance
    if gcloud compute instances describe app-prod-instance-module2 --zone=us-east1-b --project="$PROJECT_ID" &>/dev/null; then
        echo "  Deleting compute instance app-prod-instance-module2..."
        gcloud compute instances delete app-prod-instance-module2 \
            --zone=us-east1-b --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Delete storage bucket
    if gcloud storage buckets describe "gs://file-uploads-$PROJECT_ID" &>/dev/null; then
        echo "  Deleting storage bucket file-uploads-$PROJECT_ID..."
        gcloud storage rm -r "gs://file-uploads-$PROJECT_ID/" 2>/dev/null || true
    fi
    
    # Delete secret
    if gcloud secrets describe ssh-key --project="$PROJECT_ID" &>/dev/null; then
        echo "  Deleting secret ssh-key..."
        gcloud secrets delete ssh-key --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Module 3 resources  
    echo "Cleaning up Module 3 resources..."
    
    # Delete cloud function bucket
    if gcloud storage buckets describe "gs://cloud-function-bucket-module3-$PROJECT_ID" &>/dev/null; then
        echo "  Deleting storage bucket cloud-function-bucket-module3-$PROJECT_ID..."
        gcloud storage rm -r "gs://cloud-function-bucket-module3-$PROJECT_ID/" 2>/dev/null || true
    fi
    
    # Delete cloud function
    if gcloud functions describe monitoring-function --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
        echo "  Deleting cloud function monitoring-function..."
        gcloud functions delete monitoring-function \
            --region="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Delete service account
    if gcloud iam service-accounts describe "monitoring-function@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
        echo "  Deleting service account monitoring-function..."
        gcloud iam service-accounts delete \
            "monitoring-function@$PROJECT_ID.iam.gserviceaccount.com" \
            --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Module 1 resources
    echo "Cleaning up Module 1 resources..."
    
    # Delete modeldata buckets
    for bucket in $(gcloud storage ls | grep "gs://modeldata-.*-$PROJECT_ID/" || true); do
        echo "  Deleting storage bucket $bucket..."
        gcloud storage rm -r "$bucket" 2>/dev/null || true
    done
    
    # Delete bucket-service-account
    if gcloud iam service-accounts describe "bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
        echo "  Deleting service account bucket-service-account..."
        gcloud iam service-accounts delete \
            "bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
            --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Delete DevBucketAccess custom role
    if gcloud iam roles describe DevBucketAccess --project="$PROJECT_ID" &>/dev/null; then
        echo "  Deleting custom role DevBucketAccess..."
        gcloud iam roles delete DevBucketAccess --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Challenge 5 resources
    echo "Cleaning up Challenge 5 resources..."
    
    # Delete terraform-pipeline service account
    if gcloud iam service-accounts describe "terraform-pipeline@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
        echo "  Deleting service account terraform-pipeline..."
        gcloud iam service-accounts delete \
            "terraform-pipeline@$PROJECT_ID.iam.gserviceaccount.com" \
            --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
    # Delete TerraformPipelineProjectAdmin custom role
    if gcloud iam roles describe TerraformPipelineProjectAdmin --project="$PROJECT_ID" &>/dev/null; then
        echo "  Deleting custom role TerraformPipelineProjectAdmin..."
        gcloud iam roles delete TerraformPipelineProjectAdmin --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
    
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
}

# Import function for module2 resources
import_module2_resources() {
    echo "Attempting to import module2 resources into state..."
    
    # Check if instance exists and import
    if gcloud compute instances describe app-prod-instance-module2 \
        --zone=us-east1-b --project="$PROJECT_ID" &>/dev/null; then
        echo "  Importing compute instance..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_compute_instance.compute-instance-module2 \
            "projects/$PROJECT_ID/zones/us-east1-b/instances/app-prod-instance-module2" \
            2>/dev/null || true
    fi
    
    # Check if bucket exists and import
    if gcloud storage buckets describe "gs://file-uploads-$PROJECT_ID" &>/dev/null; then
        echo "  Importing storage bucket..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_storage_bucket.bucket-module2 \
            "file-uploads-$PROJECT_ID" 2>/dev/null || true
    fi
    
    # Check if secret exists and import
    if gcloud secrets describe ssh-key --project="$PROJECT_ID" &>/dev/null; then
        echo "  Importing secret..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_secret_manager_secret.ssh-secret-module2 \
            "projects/$PROJECT_ID/secrets/ssh-key" 2>/dev/null || true
    fi
}

# Import function for main terraform directory resources
import_terraform_resources() {
    echo "Attempting to import main terraform resources into state..."
    
    # Module 1 resources
    # Check if bucket-service-account exists and import
    if gcloud iam service-accounts describe "bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
        echo "  Importing bucket-service-account..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_service_account.bucket-service-account \
            "projects/$PROJECT_ID/serviceAccounts/bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
            2>/dev/null || true
    fi
    
    # Check if DevBucketAccess role exists and import
    if gcloud iam roles describe DevBucketAccess --project="$PROJECT_ID" &>/dev/null; then
        echo "  Importing DevBucketAccess role..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_project_iam_custom_role.dev-bucket-access \
            "projects/$PROJECT_ID/roles/DevBucketAccess" \
            2>/dev/null || true
    fi
    
    # Check if modeldata buckets exist and import
    if gcloud storage buckets describe "gs://modeldata-dev-$PROJECT_ID" &>/dev/null; then
        echo "  Importing modeldata-dev bucket..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_storage_bucket.modeldata-dev \
            "modeldata-dev-$PROJECT_ID" 2>/dev/null || true
    fi
    
    if gcloud storage buckets describe "gs://modeldata-prod-$PROJECT_ID" &>/dev/null; then
        echo "  Importing modeldata-prod bucket..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_storage_bucket.modeldata-prod \
            "modeldata-prod-$PROJECT_ID" 2>/dev/null || true
    fi
    
    # Module 3 resources
    # Check if monitoring-function service account exists and import
    if gcloud iam service-accounts describe "monitoring-function@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
        echo "  Importing monitoring-function service account..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_service_account.monitoring-function \
            "projects/$PROJECT_ID/serviceAccounts/monitoring-function@$PROJECT_ID.iam.gserviceaccount.com" \
            2>/dev/null || true
    fi
    
    # Check if cloud-function-bucket exists and import
    if gcloud storage buckets describe "gs://cloud-function-bucket-module3-$PROJECT_ID" &>/dev/null; then
        echo "  Importing cloud-function-bucket..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_storage_bucket.cloud-function-bucket \
            "cloud-function-bucket-module3-$PROJECT_ID" 2>/dev/null || true
    fi
    
    # Challenge 5 resources
    # Check if terraform-pipeline service account exists and import
    if gcloud iam service-accounts describe "terraform-pipeline@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
        echo "  Importing terraform-pipeline service account..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_service_account.impersonation-challenge-5 \
            "projects/$PROJECT_ID/serviceAccounts/terraform-pipeline@$PROJECT_ID.iam.gserviceaccount.com" \
            2>/dev/null || true
    fi
    
    # Check if TerraformPipelineProjectAdmin role exists and import
    if gcloud iam roles describe TerraformPipelineProjectAdmin --project="$PROJECT_ID" &>/dev/null; then
        echo "  Importing TerraformPipelineProjectAdmin role..."
        terraform import \
            -var="project_id=$PROJECT_ID" \
            -var="project_number=$PROJECT_NUMBER" \
            google_project_iam_custom_role.project-iam-setter-role-challenge5 \
            "projects/$PROJECT_ID/roles/TerraformPipelineProjectAdmin" \
            2>/dev/null || true
    fi
}

# Try terraform destroy with state import if needed
destroy_with_terraform() {
    local dir=$1
    echo "##########################################################"
    echo "> Attempting terraform destroy in $dir..."
    echo "##########################################################"
    
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist, skipping..."
        return 0
    fi
    
    cd "$dir"
    
    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        echo "Initializing terraform in $dir..."
        terraform init -input=false
    fi
    
    # Check if state is empty but resources exist
    local has_resources=$(terraform state list 2>/dev/null | grep -c "google_" || echo "0")
    
    # Handle main terraform directory
    if [ "$has_resources" -eq "0" ] && [ "$dir" = "terraform" ]; then
        echo "Warning: State appears empty, checking for orphaned resources..."
        # Only try import if resources actually exist
        if gcloud iam service-accounts describe "bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null || \
           gcloud iam service-accounts describe "monitoring-function@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null || \
           gcloud iam service-accounts describe "terraform-pipeline@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null || \
           gcloud iam roles describe DevBucketAccess --project="$PROJECT_ID" &>/dev/null || \
           gcloud iam roles describe TerraformPipelineProjectAdmin --project="$PROJECT_ID" &>/dev/null || \
           gcloud storage buckets describe "gs://modeldata-dev-$PROJECT_ID" &>/dev/null || \
           gcloud storage buckets describe "gs://modeldata-prod-$PROJECT_ID" &>/dev/null || \
           gcloud storage buckets describe "gs://cloud-function-bucket-module3-$PROJECT_ID" &>/dev/null; then
            import_terraform_resources
        fi
    fi
    
    # Handle module2 directory
    if [ "$has_resources" -eq "0" ] && [ "$dir" = "terraform_module2" ]; then
        echo "Warning: State appears empty, checking for orphaned resources..."
        # Only try import if resources actually exist
        if gcloud compute instances describe app-prod-instance-module2 --zone=us-east1-b --project="$PROJECT_ID" &>/dev/null || \
           gcloud storage buckets describe "gs://file-uploads-$PROJECT_ID" &>/dev/null || \
           gcloud secrets describe ssh-key --project="$PROJECT_ID" &>/dev/null; then
            import_module2_resources
        fi
    fi
    
    # Run destroy
    echo "Running terraform destroy..."
    terraform destroy \
        -var="project_id=$PROJECT_ID" \
        -var="project_number=$PROJECT_NUMBER" \
        -auto-approve || {
        echo "Terraform destroy encountered issues in $dir"
        cd ..
        return 1
    }
    
    cd ..
    return 0
}

# Main script starts here
echo "##########################################################"
echo "> Starting GCP AI Security Lab resource cleanup"
echo "##########################################################"

# Get project info
if [ -z "$TF_VAR_project_id" ]; then
    read -p "Your GCP project ID: " PROJECT_ID
else
    PROJECT_ID="$TF_VAR_project_id"
    echo "Using project ID from environment: $PROJECT_ID"
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" 2>/dev/null | grep projectNumber | tr -d -c 0-9)
REGION="us-east1"

if [ -z "$PROJECT_NUMBER" ]; then
    echo "Error: Could not get project number for project $PROJECT_ID"
    echo "Please ensure you have access to the project and gcloud is configured correctly."
    exit 1
fi

echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo "Region: $REGION"
echo ""

# List resources that will be destroyed
echo "##########################################################"
echo "> Scanning for resources to destroy..."
echo "##########################################################"

echo "Compute instances:"
gcloud compute instances list --filter="name:module2" --format="table(name,zone,status)" 2>/dev/null || echo "  None found"

echo ""
echo "Storage buckets:"
gcloud storage ls 2>/dev/null | grep -E "file-uploads-$PROJECT_ID|cloud-function-bucket-module3-$PROJECT_ID|modeldata-.*-$PROJECT_ID" || echo "  None found"

echo ""
echo "Secrets:"
gcloud secrets list --filter="name:ssh-key" --format="table(name)" 2>/dev/null || echo "  None found"

echo ""
echo "Cloud Functions:"
gcloud functions list --format="table(name,region)" 2>/dev/null | grep monitoring || echo "  None found"

echo ""
echo "Cloud Run services:"
gcloud run services list --format="table(name,region)" 2>/dev/null | grep cloudai-portal || echo "  None found"

echo ""
read -p "Continue with destroy? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Destroy cancelled by user"
    exit 0
fi

# Track if we need fallback cleanup
NEEDS_CLEANUP=false

# Try terraform destroy for main terraform directory
if [ -d "terraform" ]; then
    destroy_with_terraform "terraform" || NEEDS_CLEANUP=true
fi

# Try terraform destroy for module 2
if [ -d "terraform_module2" ]; then
    destroy_with_terraform "terraform_module2" || NEEDS_CLEANUP=true
fi

# Try terraform destroy for module 1
if [ -d "terraform_module1" ]; then
    destroy_with_terraform "terraform_module1" || NEEDS_CLEANUP=true
fi

# Always run direct cleanup to catch any orphaned resources
echo ""
echo "##########################################################"
echo "> Verifying all resources are destroyed..."
echo "##########################################################"
cleanup_gcp_resources

# Clean up local files and directories
echo ""
echo "##########################################################"
echo "> Cleaning up local files and directories..."
echo "##########################################################"

# Remove terraform state files
echo "Removing terraform state files..."
rm -f terraform/terraform.tfstate* 2>/dev/null || true
rm -f terraform_module2/terraform.tfstate* 2>/dev/null || true
rm -f terraform_module1/terraform.tfstate* 2>/dev/null || true

# Remove terraform lock files
echo "Removing terraform lock files..."
rm -f terraform/.terraform.lock.hcl 2>/dev/null || true
rm -f terraform_module2/.terraform.lock.hcl 2>/dev/null || true
rm -f terraform_module1/.terraform.lock.hcl 2>/dev/null || true

# Remove terraform directories
echo "Removing .terraform directories..."
rm -rf terraform/.terraform 2>/dev/null || true
rm -rf terraform_module2/.terraform 2>/dev/null || true
rm -rf terraform_module1/.terraform 2>/dev/null || true

# Remove copied module directories
echo "Removing terraform_module1 directory..."
rm -rf terraform_module1 2>/dev/null || true

# Remove temporary files
echo "Removing temporary_files directory..."
rm -rf temporary_files 2>/dev/null || true

echo ""
echo "##########################################################"
echo "> Destroy complete!"
echo "##########################################################"
echo ""
echo "All resources have been destroyed and local files cleaned up."
echo "You can now run ./challenge-setup.sh to deploy fresh resources."