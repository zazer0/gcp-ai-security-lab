#!/bin/bash

# variables
PROJECT_ID=$1
ZONE=europe-west1-b

# create a service account key for the account we will leak in challenge 1
gcloud iam service-accounts keys create challenge1-creds.json --iam-account=gkeapp-file-uploader@$PROJECT_ID.iam.gserviceaccount.com

# set up connection to the gke cluster created in challenge 1
gcloud container clusters get-credentials gke-cluster-challenge-1 --zone $ZONE --project $PROJECT_ID

# create a kubernetes secret containing the service account key
kubectl create secret generic gkeapp-file-uploader-account --from-file=./challenge1-creds.json

#ToDo:
# create misconfigured role binding to system-authenticated -> this opens up the challenge and makes the project vulnerable from outside attacks.
