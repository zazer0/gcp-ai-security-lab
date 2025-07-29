#!/bin/bash

# mod2-setup.sh - Module 2 specific setup tasks
# Called from challenge-setup.sh after terraform apply

# Check if required parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <PROJECT_ID> <PROJECT_NUMBER>"
    exit 1
fi

PROJECT_ID=$1
PROJECT_NUMBER=$2

echo "##########################################################"
echo "> Setup for module 2."
echo "##########################################################"

ZONE=$(gcloud compute instances list --project $PROJECT_ID | grep module2 | awk '{print$2}')

# upload the state file to the storage bucket
gcloud storage cp ./terraform_module2/terraform.tfstate gs://file-uploads-$PROJECT_ID/infrastructure_config.tfstate

COMPUTE_IP=$(gcloud compute instances describe app-prod-instance-module2 --zone $ZONE --project $PROJECT_ID | grep natIP | awk '{print $2}')
echo "You found flag 1!" > temporary_files/flag1.txt
scp -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no temporary_files/flag1.txt alice@$COMPUTE_IP:/home/alice/

# Get CloudAI Portal URL from terraform output
PORTAL_URL=$(cd terraform && terraform output -raw cloudai_portal_url 2>/dev/null || echo "Portal deployment pending")

# Create monitoring UI info file
cat > temporary_files/monitoring_ui_info.txt << EOF
CloudAI Labs Monitoring Interface
=================================

Access the web-based monitoring dashboard at:
$PORTAL_URL/monitoring

This interface provides a user-friendly way to interact with the monitoring function.
You can also use the command-line script: invoke_monitoring_function.sh

For the admin console (requires authentication):
$PORTAL_URL/admin
EOF

# Upload monitoring UI info to VM
scp -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no temporary_files/monitoring_ui_info.txt alice@$COMPUTE_IP:/home/alice/

echo "> Module 2 setup complete!"
echo "> Monitoring UI info uploaded to VM"
