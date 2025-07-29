# CloudAI Labs Security Bootcamp: Module Overview & UI Integration Plan

## Project Context
CloudAI Labs is a fictional ML model hosting platform used to teach GCP security through hands-on exploitation. Students progress through 4 modules, each building on discoveries from the previous one.

## Learning Modules Overview

### Module 1: Public Bucket Exposure
**Scenario:** CloudAI Labs' dev bucket exposed, containing "leaked GPT-5 benchmarks"  
**Skills:** Cloud storage enumeration, service account compromise  
**Infrastructure:** 
- Dev bucket: `modeldata-dev-[PROJECT_ID]` (public read)
- Prod bucket: `modeldata-prod-[PROJECT_ID]` (requires auth)
**Key Files:** 
- `flag1_gpt5_benchmarks.txt` (first flag)
- `bucket-service-account.json` (leads to Module 2)
**Setup Script:** `mod1-setup.sh`

### Module 2: Infrastructure as Code Secrets  
**Scenario:** Production bucket contains terraform state with SSH keys  
**Skills:** State file analysis, SSH key extraction, lateral movement  
**Infrastructure:**
- Compute instance: `app-prod-instance-module2`
- SSH user: `alice`
**Key Files:** 
- `terraform.tfstate` in prod bucket
- Encoded SSH private key in state file
**Setup Script:** `mod2-setup.sh`

### Module 3: Metadata Service Exploitation
**Scenario:** Monitoring function vulnerable to SSRF attacks  
**Skills:** SSRF exploitation, metadata service abuse, token theft  
**Infrastructure:**
- Cloud Function: `monitoring-function`
- Vulnerable endpoint accepts `metadata` parameter
**Exploit:** 
```bash
curl -X POST [FUNCTION_URL] -d '{"metadata":"token"}'
```
**Key Discovery:** Function's service account token

### Module 4: IAM Privilege Escalation
**Scenario:** Compromised account can impersonate terraform pipeline  
**Skills:** IAM analysis, service account impersonation, persistence  
**Infrastructure:**
- Service Account: `terraform-pipeline`
- Custom Role: `TerraformPipelineProjectAdmin`
**Goal:** Add personal Google account to project using impersonation

## Web Portal Integration

### Architecture
Single Cloud Function (`cloudai-portal`) with routes:
- `/` - Homepage
- `/docs` - Developer documentation (Module 1)
- `/status` - Deployment status (Module 2)
- `/monitoring` - Monitoring dashboard (Module 3)
- `/admin` - Admin console (Module 4)
- `/api/v1/*` - Model inference API

### Module-Specific Web Features

**Module 1:** Docs page shows bucket names in code examples  
**Module 2:** Status page reveals terraform state location  
**Module 3:** Web form for SSRF attacks, visual token extraction  
**Module 4:** Token-gated admin panel with IAM visualizer

### Implementation Phases

**Phase 1:** Basic portal with docs and API  
**Phase 2:** Status page and monitoring dashboard  
**Phase 3:** Admin console with IAM explorer

### Key Benefits
- Browser + terminal paths for each module
- Visual learning for complex concepts (IAM, tokens)
- Realistic cloud platform experience
- No changes to existing infrastructure

### Setup Flow
1. Deploy existing terraform infrastructure
2. Run module setup scripts
3. Deploy portal Cloud Function
4. Students access via browser or terminal