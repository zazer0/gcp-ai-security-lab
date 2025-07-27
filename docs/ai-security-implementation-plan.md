# AI Security Bootcamp Implementation Plan

> Context: "CloudAI Labs" - A model hosting platform (like Hugging Face) with security flaws

## Implementation Details

### Code Structure
- Reuse existing terraform files
- Add simple Flask ML API
- Pre-deploy vulnerable notebooks

### Student Experience  
- ~30 minutes per module
- Story → Attack → Fix
- Visual diagrams provided

### Simplifications
- No Kubernetes
- Pre-configured gcloud
- Focus: Storage, Functions, IAM

# Modules

## Module 1: Enumeration and Discovery
**Attack**:
- Predictable bucket names: modeldata-{dev,prod}
  - Student given 'modeldata-dev' bucket to start
- Dev bucket has a 'bucket-service-account'.json
- The 'bucket-service-account' has access to 'modeldata-prod' bucket
- Hints:
  - Hint1: "what's in the bucket? any creds?"
  - Hint2: "what can those creds access? (insert use-creds-command here)
  - Hint3: "what if there was another bucket for prod?"

**Remediation**:
- Go to Cloud Storage → Select "cloudai-dev" bucket
  - Delete the service account json from the bucket
- Go to IAM, Create new Service Account 'dev-bucket-sa'
  - Student selects tf-preconfigured 'Dev Bucket Access' role

**Engagement**: "CloudAI's 'secret' GPT-5 benchmarks leaked. No insider needed - how?"


## Module 2: Environment Secrets & State Exposure
**Attack** (Adapt Challenge 3):
- `gsutil ls` newly discovered 'modeldata-prod' bucket
  - Discover + download Terraform Statefile
- Examine file, notice 'alice' user, and 'nat' IP
  - Also notice "SSH key" secret visible in encoded form
- Decode SSH Key, dump to local file
  - Use it to `ssh alice@nat-ip` to access deployed VM

**Remediation**:
Prevent decodable SSH Key
- Open GCP Console → Security → Secret Manager
- Click "Create Secret", name: "ssh-key"
- Paste the exposed SSH key, click "Create"

**Engagement**: "Your startup's LLM architecture leaked. Trace the breach through exposed deployment files."

## Module 3: Instance Metadata Service Exploitation  
**Attack** (Use Challenge 4):
- SSRF in model inference API
- Extract service account via metadata
- Pivot to training infrastructure

**Remediation**:
- Go to IAM & Admin → Service Accounts → Create
- Name: "model-api-vm", description: "Minimal VM account"
- Skip permissions for now → Create
- Compute Engine → VM instances → Click instance
- Edit → Service account → Select "model-api-vm"
- Save → Test: SSRF gets limited token

**Engagement**: "Inference costs exploded overnight. The model API is accessing internal resources."

## Module 4: Service Account Misconfigurations [Extension]
**Attack** (Use Challenge 5):
- Chain service account impersonations
- Escalate inference-api@ → ml-admin@
- Delete model repository (demonstration)

**Remediation**:
- Navigate to IAM & Admin → Service Accounts
- Find "inference-api@" account → View permissions
- Click pencil icon next to "Service Account Token Creator"
- Select "Remove" → Confirm removal
- Create new role: "Model Inference Only" with minimal perms
- Test: Impersonation chain now broken

**Engagement**: "Ex-employee claims they deleted all models using just an API token. Investigate."

