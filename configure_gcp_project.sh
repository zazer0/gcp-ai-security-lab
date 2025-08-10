#!/bin/bash

PROJECT_ID=${TF_VAR_project_id}
echo "Parsed ${PROJECT_ID} from env! Running setup commands..."

sleep 2

gcloud compute disks list || gcloud auth login
gcloud config set project "$PROJECT_ID"
gcloud auth application-default login
gcloud auth application-default set-quota-project "$PROJECT_ID"
