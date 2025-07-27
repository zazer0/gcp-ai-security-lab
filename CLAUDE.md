# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a GCP CTF (Capture The Flag) workshop that creates intentionally vulnerable Google Cloud Platform infrastructure for security education. It includes 3 progressive security challenges teaching cloud exploitation techniques.

## Essential Commands

### Setup and Teardown
- **Deploy infrastructure**: `./challenge-setup.sh` - Interactive script that provisions all GCP resources
- **Destroy infrastructure**: `./challenge-destroy.sh` - Cleans up all resources and credentials

### Working with Terraform
- **Initialize**: `cd terraform && terraform init` (or `cd terraform_challenge3` for module 2)
- **Plan changes**: `terraform plan`
- **Apply changes**: `terraform apply`
- **Destroy resources**: `terraform destroy`


## Architecture Overview

### Infrastructure Layout
- **terraform/**: Main infrastructure for challenges 2 and 3
  - Creates storage buckets, cloud functions, service accounts
- **terraform_challenge3/**: Separate infrastructure for challenge 1
  - Creates compute instances with specific SSH configurations and storage bucket
- **temporary_files/**: Generated credentials (gitignored, created during setup)

### Key GCP Resources Created
1. **Storage Buckets**: Multiple buckets with varying access controls
2. **Compute Instances**: VMs with specific metadata/SSH configurations
3. **Cloud Functions**: Python functions with metadata endpoint vulnerabilities
4. **Service Accounts**: Various accounts with different permission levels

### Security Challenges Structure
Each challenge (1-3) involves:
- Specific misconfiguration or vulnerability
- Flag hidden in GCP resources
- Progressive difficulty
- Solution available in solution.md

## Development Guidelines

### Adding New Challenges
1. Create terraform configuration in appropriate directory
2. Add hint file to `hints/` directory
3. Update solution.md with walkthrough
4. Test full setup/teardown cycle

### Modifying Infrastructure
- Always test with `terraform plan` before applying
- Ensure resources are properly tagged for cleanup
- Update challenge-setup.sh if new manual steps needed

### Important Warnings
- **NEVER deploy to production environments** - intentionally vulnerable
- Requires GCP project with Owner permissions
- All generated credentials stored in temporary_files/ (gitignored)
- Always run challenge-destroy.sh after workshop completion