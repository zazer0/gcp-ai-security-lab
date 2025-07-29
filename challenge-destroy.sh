#! /bin/bash

# variables
if [ -z "$TF_VAR_project_id" ] ; then
    read -p "Your GCP project ID: " PROJECT_ID
else
    echo "Read TF Var ProjectID = ${TF_VAR_project_id}"
fi

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID | grep projectNumber | tr -d -c 0-9)

# destroy resources with terraform
cd terraform
terraform destroy -var project_id="$PROJECT_ID" -var project_number="$PROJECT_NUMBER" -auto-approve
cd ../

# destroy resources for module 2 with terraform
cd terraform_module2
terraform destroy -var project_id="$PROJECT_ID" -var project_number="$PROJECT_NUMBER" -auto-approve
cd ../

# Destroy Module 1 resources
if [ -d "terraform_module1" ]; then
    echo "Destroying Module 1 resources..."
    cd terraform_module1
    terraform destroy -auto-approve -var project_id="$PROJECT_ID" -var project_number="$PROJECT_NUMBER"
    cd ..
    rm -rf terraform_module1
fi

# clean up credential files we created
rm -rf ./temporary_files
