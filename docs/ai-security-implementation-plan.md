# AI Security Bootcamp Implementation Plan

## Context: "CloudAI Labs" - A model hosting platform (like Hugging Face) with security flaws

## Module 1: Environment Secrets & State Exposure
**Attack** (Adapt Challenge 3):
- Find terraform state in public model bucket
- Extract SSH keys and API tokens
- Access dev server, steal proprietary models

**Remediation**:
- Secure state backend with encryption
- Migrate secrets to Secret Manager
- Private buckets with signed URLs

**Engagement**: "Your startup's LLM architecture leaked. Trace the breach through exposed deployment files."

## Module 2: Instance Metadata Service Exploitation  
**Attack** (Use Challenge 4):
- SSRF in model inference API
- Extract service account via metadata
- Pivot to training infrastructure

**Remediation**:
- Enable IMDSv2, disable for functions
- URL allowlisting for model loading
- VPC Service Controls for ML workloads

**Engagement**: "Inference costs exploded overnight. The model API is accessing internal resources."

## Module 3: Service Account Misconfigurations
**Attack** (Use Challenge 5):
- Chain service account impersonations
- Escalate inference-api@ → ml-admin@
- Delete model repository (demonstration)

**Remediation**:
- Least-privilege service accounts
- Workload Identity for ML jobs
- IAM alerts and monitoring

**Engagement**: "Ex-employee claims they deleted all models using just an API token. Investigate."

## Module 4: Enumeration & Discovery
**Attack** (New simple implementation):
- Predictable bucket names: cloudai-{dev,staging,prod}
- Exposed Jupyter notebooks with secrets
- Unprotected MLflow experiments

**Remediation**:
- Non-predictable resource naming
- API Gateway with authentication
- Audit logs with enumeration alerts

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