# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is an AI Security workshop for cloud security education, centered around "CloudAI Labs" - a fictional model hosting platform (similar to Hugging Face) with intentional security vulnerabilities. The workshop is an 8-hour experience with 4 progressive modules of increasing complexity (30 min, 1 hr, 2 hrs, 3 hrs) teaching cloud exploitation and remediation techniques specifically relevant to AI/ML workloads.

## Essential Commands

### Setup and Teardown
- **Deploy infrastructure**: `./challenge-setup.sh` - Interactive script that provisions all GCP resources
- **Destroy infrastructure**: `./challenge-destroy.sh` - Cleans up all resources and credentials

### Working with Terraform
- **Initialize**: `cd terraform && terraform init` (or `cd terraform_module2` for module 2)
- **Plan changes**: `terraform plan`
- **Apply changes**: `terraform apply`
- **Destroy resources**: `terraform destroy`

### Module Validation
- **Module 1**: `./validate-m1.sh` - Validate enumeration fixes
- **Module 2**: `./validate-m2.sh` - Validate state exposure remediation
- **Module 3**: `./validate-m3.sh` - Validate IMDS hardening
- **Module 4**: `./validate-m4.sh` - Validate IAM improvements


## Architecture Overview

### Infrastructure Layout
- **terraform/**: Main infrastructure for modules 3 and 4
  - Creates cloud functions with SSRF vulnerabilities, service accounts with misconfigurations
  - Includes Flask ML API deployment
- **terraform_module2/**: Infrastructure for module 2
  - Creates compute instances with SSH access and exposed terraform state
- **terraform_module1/**: Infrastructure for module 1 (new)
  - Creates predictable bucket naming (modeldata-dev, modeldata-prod)
  - Deploys service account credentials in dev bucket
- **temporary_files/**: Generated credentials (gitignored, created during setup)

### Key GCP Resources Created
1. **Storage Buckets**: Predictably named buckets (modeldata-dev/prod) with varying access controls
2. **Compute Instances**: VMs with exposed SSH keys and default service accounts
3. **Cloud Functions**: Python monitoring functions with SSRF vulnerabilities targeting metadata endpoints
4. **Service Accounts**: Multiple accounts demonstrating privilege escalation paths
5. **Flask ML API**: Simple model serving API demonstrating real-world AI platform patterns

### Module Structure
Each module follows a "Story → Attack → Fix" workflow:

#### Module 1: Enumeration & Discovery (30 minutes)
- **Attack**: Discover predictable bucket names, find leaked service account credentials
- **Remediation**: Remove exposed credentials, implement proper IAM roles
- **AI Context**: "CloudAI's 'secret' GPT-5 benchmarks leaked"

#### Module 2: Environment Secrets & State Exposure (1 hour)
- **Attack**: Extract SSH keys from exposed terraform state file
- **Remediation**: Secure state storage, use Secret Manager
- **AI Context**: "Your startup's LLM architecture leaked through deployment files"

#### Module 3: Instance Metadata Service (IMDS) Exploitation (2 hours)
- **Attack**: Use SSRF in monitoring function to extract service account tokens
- **Remediation**: Configure minimal VM service accounts, fix SSRF vulnerability
- **AI Context**: "Inference costs exploded - model API accessing internal resources"

#### Module 4: Service Account Misconfigurations (3 hours)
- **Attack**: Escalate privileges through service account impersonation chain
- **Remediation**: Remove unnecessary Token Creator permissions
- **AI Context**: "Ex-employee claims they deleted all models using just an API token"

## Development Guidelines

### Module Development Workflow
1. **Story First**: Create engaging AI/ML security scenario
2. **Attack Lab**: Design vulnerable infrastructure in terraform
3. **Remediation Lab**: Create fix procedures using GCP Console
4. **Validation**: Write validation script for both attack and fix
5. **Documentation**: Update hints/ and solution.md
6. **Visual Aids**: Add architecture diagrams for attack paths

### Adding New Modules
1. Create terraform configuration in `terraform_module[N]/`
2. Add hints to `hints/module[N]/` directory  
3. Create validation script `validate-m[N].sh`
4. Update solution.md with complete walkthrough
5. Test full setup/teardown cycle
6. Ensure appropriate completion time (30 min to 3 hours based on complexity)

### Modifying Infrastructure
- Always test with `terraform plan` before applying
- Ensure resources are properly tagged for cleanup
- Update challenge-setup.sh if new manual steps needed
- Use pre-configured gcloud authentication
- Focus on Storage, Functions, and IAM only (no Kubernetes)

### Important Warnings
- **NEVER deploy to production environments** - intentionally vulnerable
- **For AI security education** - focuses on vulnerabilities specific to ML platforms
- Requires GCP project with Owner permissions
- All generated credentials stored in temporary_files/ (gitignored)
- Always run challenge-destroy.sh after workshop completion
- Pre-configured gcloud CLI access required for simplified experience