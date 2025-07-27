#!/bin/bash

# variables
read -p "Your GCP project ID: " PROJECT_ID
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
echo "> Beginning terraform setup for - module 2."
echo "##########################################################"
cd terraform_module2
terraform init -input=false
terraform plan -out tf.out -var project-id="$PROJECT_ID" -var project-number="$PROJECT_NUMBER" -input=false
terraform apply -input=false "tf.out"
cd ../

# set up resources with terraform
echo "##########################################################"
echo "> Beginning terraform setup for - challenges 4 and 5."
echo "##########################################################"

cd terraform
terraform init -input=false
terraform plan -out tf.out -var project-id="$PROJECT_ID" -var project-number="$PROJECT_NUMBER" -input=false
terraform apply -input=false "tf.out"
cd ../

echo "##########################################################"
echo "> Setup for module 2."
echo "##########################################################"

ZONE=$(gcloud compute instances list  --project $PROJECT_ID | grep module2 | awk '{print$2}')

# upload the state file to the storage bucket
gcloud storage cp ./terraform_module2/terraform.tfstate gs://file-uploads-$PROJECT_ID

COMPUTE_IP=$(gcloud compute instances describe  app-prod-instance-module2 --zone $ZONE --project $PROJECT_ID | grep natIP | awk '{print $2}')
echo "You found flag 1!" > temporary_files/flag1.txt
scp -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no temporary_files/flag1.txt alice@$COMPUTE_IP:/home/alice/

echo "##########################################################"
echo "> Setup for challenge 4."
echo "##########################################################"
#
# copy function invocation script on compute engine
scp -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no ./invoke_monitoring_function.sh alice@$COMPUTE_IP:/tmp
# make the script executable and not writeable and owned by root
ssh -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no alice@$COMPUTE_IP "sudo mv /tmp/invoke_monitoring_function.sh /usr/local/bin/; cd /home/alice && ln -s /usr/local/bin/invoke_monitoring_function.sh; sudo chmod 755 /usr/local/bin/invoke_monitoring_function.sh; sudo chown root:root /usr/local/bin/invoke_monitoring_function.sh"
# drop sudo privileges for alice
ssh -i temporary_files/leaked_ssh_key -o StrictHostKeyChecking=no alice@$COMPUTE_IP "sudo deluser alice google-sudoers"
# copy the function source code directly on the bucket
gsutil cp terraform/script/main.py gs://cloud-function-bucket-challenge4-$PROJECT_ID/
# remove the function zip file from the storage bucket to not mislead players to try and extract it
gsutil rm gs://cloud-function-bucket-challenge4-$PROJECT_ID/main.zip




echo "##########################################################"
echo "> Challenge setup complete!"
echo "##########################################################"
