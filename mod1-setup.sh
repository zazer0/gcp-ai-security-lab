#!/bin/bash

# mod1-setup.sh - Module 1 specific setup tasks
# Called from challenge-setup.sh after terraform apply

# Check if required parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <PROJECT_ID> <PROJECT_NUMBER>"
    exit 1
fi

PROJECT_ID=$1
PROJECT_NUMBER=$2

echo "##########################################################"
echo "> Setup for module 1."
echo "##########################################################"

# Decode and save the service account key to temporary file
SA_KEY=$(cd terraform_module1 && terraform show -json | jq -r '.values.root_module.resources[] | select(.name=="bucket-sa-key") | .values.private_key' | base64 -d)
echo "$SA_KEY" > temporary_files/bucket-service-account.json

# Upload service account key to dev bucket
gsutil cp temporary_files/bucket-service-account.json gs://modeldata-dev-$PROJECT_ID/

# Create flag file in prod bucket
echo "You found flag 1! CloudAI's GPT-5 benchmarks: 99.9% on all tasks!" > temporary_files/flag1_gpt5_benchmarks.txt
gsutil cp temporary_files/flag1_gpt5_benchmarks.txt gs://modeldata-prod-$PROJECT_ID/secret_benchmarks/

# Create some decoy files in dev bucket
echo "Model training logs - nothing sensitive here" > temporary_files/training_logs.txt
echo "Development models - v0.1-alpha" > temporary_files/dev_models.txt
gsutil cp temporary_files/training_logs.txt gs://modeldata-dev-$PROJECT_ID/
gsutil cp temporary_files/dev_models.txt gs://modeldata-dev-$PROJECT_ID/

echo "> Module 1 setup complete!"