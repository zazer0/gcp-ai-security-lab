# AI Security Bootcamp Implementation Plan

## Context: "CloudAI Labs" - A model hosting platform (like Hugging Face) with security flaws

## Module 1: Environment Secrets & State Exposure
**Attack** (Adapt Challenge 3):
- Find terraform state in public model bucket
- Extract SSH keys and API tokens
- Access dev server, steal proprietary models

**Remediation**:
- Open GCP Console → Security → Secret Manager
- Click "Create Secret", name: "ssh-key"
- Paste the exposed SSH key, click "Create"
- Go to IAM → Service Accounts → Edit permissions
- Remove key access, add "Secret Manager User" role
- Test: SSH fails, secret access works

**Engagement**: "Your startup's LLM architecture leaked. Trace the breach through exposed deployment files."

## Module 2: Instance Metadata Service Exploitation  
**Attack** (Use Challenge 4):
- SSRF in model inference API
- Extract service account via metadata
- Pivot to training infrastructure

**Remediation**:
- Go to Compute Engine → VM instances
- Click instance name → Edit
- Scroll to "Metadata" section
- Toggle OFF "Enable the Compute Engine metadata server"
- Click "Save" at bottom
- Test: SSRF to 169.254.169.254 now fails

**Engagement**: "Inference costs exploded overnight. The model API is accessing internal resources."

## Module 3: Service Account Misconfigurations
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

## Module 4: Enumeration & Discovery
**Attack** (New simple implementation):
- Predictable bucket names: cloudai-{dev,staging,prod}
- Exposed Jupyter notebooks with secrets
- Unprotected MLflow experiments

**Remediation**:
- Go to Cloud Storage → Select "cloudai-dev" bucket
- Click "Permissions" tab → Remove "allUsers"
- Click "Configuration" → Edit bucket name
- Rename to include random suffix: "cloudai-dev-7x9k2"
- Enable "Access logs" → Select log bucket
- Test: Old URLs return 404, logs show attempts

**Engagement**: "CloudAI's 'secret' GPT-5 benchmarks leaked. No insider needed - how?"

## Implementation Details

### Code Structure
- Reuse existing terraform files
- Add simple Flask ML API
- Pre-deploy vulnerable notebooks

### Student Experience  
- 90 minutes per module
- Story → Attack → Fix
- Visual diagrams provided

### Simplifications
- No Kubernetes
- Pre-configured gcloud
- Focus: Storage, Functions, IAM