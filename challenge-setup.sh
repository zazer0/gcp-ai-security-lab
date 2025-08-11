#!/bin/bash

# variables
if [ -z "$TF_VAR_project_id" ] ; then
    read -p "Your GCP project ID: " PROJECT_ID
else
    echo "Read TF Var ProjectID = ${TF_VAR_project_id}"
fi

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID | grep projectNumber | tr -d -c 0-9)

#  create directory for temporary files
mkdir temporary_files

# Module 1 setup - Create terraform_module1 directory for separate state
echo "##########################################################"
echo "> Beginning terraform setup for - Module 1."
echo "##########################################################"
mkdir -p terraform_module1
cp terraform/module1.tf terraform_module1/
cp terraform/variables.tf terraform_module1/
cp terraform/provider.tf terraform_module1/

cd terraform_module1
terraform init -input=false
terraform plan -out tf.out -var project_id="$PROJECT_ID" -var project_number="$PROJECT_NUMBER" -input=false
terraform apply -input=false "tf.out"
cd ../

# Call Module 1 specific setup script
./mod1-setup.sh "$PROJECT_ID" "$PROJECT_NUMBER"

#
# the compute engine for module 2 gets created in its own terraform run
# this is done to get an extra state file that we can leak on the storage bucket
# create it first so that we have the state file, and to give it some time to boot
# create ssh key for vulnerable compute VM
if [ ! -f temporary_files/leaked_ssh_key ]; then
ssh-keygen -t ed25519 -C "alice" -f temporary_files/leaked_ssh_key -N ''
fi

echo "##########################################################"
echo "> Beginning terraform setup for - Module 2."
echo "##########################################################"
cd terraform_module2
terraform init -input=false
terraform plan -out tf.out -var project_id="$PROJECT_ID" -var project_number="$PROJECT_NUMBER" -input=false
terraform apply -input=false "tf.out"
cd ../

# set up resources with terraform
echo "##########################################################"
echo "> Beginning terraform setup for - challenges 4 and 5."
echo "##########################################################"

cd terraform
terraform init -input=false

# Import Module 1 resources that were created in terraform_module1
echo "> Checking for existing Module 1 resources to import..."

# Import bucket-service-account if it exists
if gcloud iam service-accounts describe "bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" &>/dev/null; then
    echo "  Importing bucket-service-account..."
    terraform import \
        -var="project_id=$PROJECT_ID" \
        -var="project_number=$PROJECT_NUMBER" \
        google_service_account.bucket-service-account \
        "projects/$PROJECT_ID/serviceAccounts/bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
        2>/dev/null || true
fi

# Import DevBucketAccess custom role if it exists
if gcloud iam roles describe DevBucketAccess --project="$PROJECT_ID" &>/dev/null; then
    echo "  Importing DevBucketAccess role..."
    terraform import \
        -var="project_id=$PROJECT_ID" \
        -var="project_number=$PROJECT_NUMBER" \
        google_project_iam_custom_role.dev-bucket-access \
        "projects/$PROJECT_ID/roles/DevBucketAccess" \
        2>/dev/null || true
fi

# Import modeldata-dev bucket if it exists
if gsutil ls -b "gs://modeldata-dev-$PROJECT_ID" &>/dev/null; then
    echo "  Importing modeldata-dev bucket..."
    terraform import \
        -var="project_id=$PROJECT_ID" \
        -var="project_number=$PROJECT_NUMBER" \
        google_storage_bucket.modeldata-dev \
        "$PROJECT_ID/modeldata-dev-$PROJECT_ID" \
        2>/dev/null || true
fi

# Import modeldata-prod bucket if it exists  
if gsutil ls -b "gs://modeldata-prod-$PROJECT_ID" &>/dev/null; then
    echo "  Importing modeldata-prod bucket..."
    terraform import \
        -var="project_id=$PROJECT_ID" \
        -var="project_number=$PROJECT_NUMBER" \
        google_storage_bucket.modeldata-prod \
        "$PROJECT_ID/modeldata-prod-$PROJECT_ID" \
        2>/dev/null || true
fi

# Import IAM bindings if they exist
# Note: These may fail if the exact member format doesn't match, but that's ok
echo "  Attempting to import IAM bindings..."
terraform import \
    -var="project_id=$PROJECT_ID" \
    -var="project_number=$PROJECT_NUMBER" \
    google_storage_bucket_iam_member.dev-bucket-access \
    "b/modeldata-dev-$PROJECT_ID roles/storage.objectViewer serviceAccount:bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    2>/dev/null || true

terraform import \
    -var="project_id=$PROJECT_ID" \
    -var="project_number=$PROJECT_NUMBER" \
    google_storage_bucket_iam_member.prod-bucket-access \
    "b/modeldata-prod-$PROJECT_ID roles/storage.objectViewer serviceAccount:bucket-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    2>/dev/null || true

echo "> Import complete, continuing with terraform plan..."

terraform plan -out tf.out -var project_id="$PROJECT_ID" -var project_number="$PROJECT_NUMBER" -input=false
terraform apply -input=false "tf.out"
cd ../

# Call Module 2 specific setup script
./mod2-setup.sh "$PROJECT_ID" "$PROJECT_NUMBER"

echo "##########################################################"
echo "> Setup for module 3."
echo "##########################################################"

ZONE=$(gcloud compute instances list --project $PROJECT_ID | grep module2 | awk '{print$2}')
COMPUTE_IP=$(gcloud compute instances describe app-prod-instance-module2 --zone $ZONE --project $PROJECT_ID | grep natIP | awk '{print $2}')

# Get the monitoring function URL and save it to a file
LOCATION="us-east1"
FUNCTION_URL=$(gcloud run services describe monitoring-function --region=$LOCATION --format='value(status.url)')
echo "Function URL: $FUNCTION_URL"

# copy function invocation script on compute engine
scp -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no ./invoke_monitoring_function.sh alice@$COMPUTE_IP:/tmp
# make the script executable and not writeable and owned by root
ssh -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no alice@$COMPUTE_IP "sudo mv /tmp/invoke_monitoring_function.sh /usr/local/bin/; cd /home/alice && ln -s /usr/local/bin/invoke_monitoring_function.sh; sudo chmod 755 /usr/local/bin/invoke_monitoring_function.sh; sudo chown root:root /usr/local/bin/invoke_monitoring_function.sh"
# Save the function URL to a file on the VM for the invocation script
ssh -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no alice@$COMPUTE_IP "echo '$FUNCTION_URL' > /home/alice/.function_url"
# drop sudo privileges for alice
ssh -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no alice@$COMPUTE_IP "sudo deluser alice google-sudoers"
# copy the function source code directly on the bucket
gsutil cp terraform/script/main.py gs://cloud-function-bucket-module3-$PROJECT_ID/
# remove the function zip file from the storage bucket to not mislead players to try and extract it
gsutil rm gs://cloud-function-bucket-module3-$PROJECT_ID/main.zip

# Get CloudAI Portal URL
PORTAL_URL=$(cd terraform && terraform output -raw cloudai_portal_url 2>/dev/null || echo "Portal not deployed")

echo "##########################################################"
echo "> Switching to student-workshop service account"
echo "##########################################################"

echo "##########################################################"
echo "> Ensuring clean admin configuration backup"
echo "##########################################################"

# ALWAYS start from default configuration to ensure clean state
echo "> Switching to default configuration..."
gcloud config configurations activate default

# Get the admin account from default configuration
DEFAULT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -z "$DEFAULT_ACCOUNT" ]; then
    echo "ERROR: No account found in default configuration"
    echo "Please run: gcloud auth login"
    exit 1
fi

echo "  Default configuration account: $DEFAULT_ACCOUNT"

# Delete any existing admin-backup to ensure it's clean
if gcloud config configurations describe admin-backup &>/dev/null; then
    echo "  Removing existing admin-backup configuration..."
    gcloud config configurations delete admin-backup --quiet 2>/dev/null || true
fi

# Create fresh admin-backup from default
echo "  Creating fresh admin-backup configuration..."
gcloud config configurations create admin-backup 2>/dev/null
gcloud config configurations activate admin-backup
gcloud config set project "$PROJECT_ID"
gcloud config set account "$DEFAULT_ACCOUNT"

echo "✓ Admin backup created with account: $DEFAULT_ACCOUNT"

gcloud config configurations list

# Extract student-workshop service account key from terraform
echo "> Extracting student-workshop service account credentials..."
cd terraform_module1
STUDENT_KEY=$(terraform output -raw student_workshop_key 2>/dev/null)
STUDENT_EMAIL=$(terraform output -raw student_workshop_email 2>/dev/null)
cd ..

# Save the key to a file
echo "$STUDENT_KEY" | base64 -d > temporary_files/student-workshop-key.json

# Create new configuration for student workshop
echo "> Creating student-workshop configuration..."
gcloud config configurations create student-workshop --activate 2>/dev/null || true
gcloud config set project "$PROJECT_ID"

# Activate the student-workshop service account
echo "> Activating student-workshop service account..."
gcloud auth activate-service-account "$STUDENT_EMAIL" --key-file=temporary_files/student-workshop-key.json

# Set this as the active account
gcloud config set account "$STUDENT_EMAIL"

echo ""
echo "##########################################################"
echo "> Account switch complete!"
echo "##########################################################"
echo "> Current active account: $STUDENT_EMAIL"
echo "> This account has LIMITED permissions (dev bucket only)"
echo "> Students must find and use bucket-service-account"
echo "> credentials in the dev bucket to access prod resources"
echo ""
echo "> To switch back to admin: gcloud config configurations activate admin-backup"
echo ""

echo "##########################################################"
echo "> Challenge setup complete!"
echo "##########################################################"
echo ""
echo "CloudAI Labs Portal: $PORTAL_URL"
echo "Start by exploring: gs://modeldata-dev-$PROJECT_ID/"
echo "Portal info available at: gs://modeldata-dev-$PROJECT_ID/portal_info.txt"
echo ""
