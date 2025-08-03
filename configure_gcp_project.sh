#!/bin/bash



PROJECT_ID=${TF_VAR_project_id}
echo "Parsed ${PROJECT_ID} from env!"

sleep 2

gcloud config set project "$PROJECT_ID"
gcloud auth application-default set-quota-project "$PROJECT_ID"
