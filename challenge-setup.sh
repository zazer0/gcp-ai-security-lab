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

echo "##########################################################"
echo "> Challenge setup complete!"
echo "##########################################################"
