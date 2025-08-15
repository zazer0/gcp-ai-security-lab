[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# GCP AI Security Lab

> [!WARNING]  
> **This creates intentionally vulnerable infrastructure for educational purposes.**  
> Never deploy this in a production environment or shared GCP project.

A hands-on Google Cloud Platform (GCP) security workshop featuring 3 progressive Capture The Flag (CTF) challenges. Learn cloud exploitation techniques by attacking intentionally misconfigured GCP infrastructure.

## 🎯 Challenge Overview

### Module 1: Cloud Storage Enumeration & Discovery
- **Target**: Find leaked GPT-6 benchmark results
- **Skills**: Bucket enumeration, service account privilege escalation
- **Techniques**: Predictable naming patterns, credential discovery

### Module 2: Metadata Service Exploitation  
- **Target**: Compromise compute instances via metadata endpoints
- **Skills**: SSH key extraction, terraform state file analysis
- **Techniques**: IMDS attacks, infrastructure as code vulnerabilities

### Module 3: Cloud Function & IAM Exploitation
- **Target**: Escalate through cloud functions and service accounts
- **Skills**: Function enumeration, IAM policy exploitation  
- **Techniques**: Serverless security, privilege escalation chains

## 🚀 Quick Start

### Prerequisites
- GCP account with **Owner** permissions on a dedicated project
- `terraform` (>= 1.0)
- `gcloud` CLI configured
- `gsutil` available

### Setup
```bash
# Deploy all infrastructure
./challenge-setup.sh

# Individual module setup (optional)
./mod1-setup.sh  # Module 1 only
./mod2-setup.sh  # Module 2 only
```

### Validation
```bash
# Verify module deployments
./validate-m1.sh
./validate-m2.sh  
./validate-m3.sh
```

### Cleanup
```bash
# Destroy all resources and cleanup credentials
./challenge-destroy.sh
```

## 📁 Repository Structure

```
├── terraform/              # Main infrastructure (modules 2-3)
├── terraform_module1/      # Module 1 infrastructure  
├── terraform_module2/      # Module 2 infrastructure
├── hints/                  # Challenge hints and guidance
├── docs/                   # Implementation documentation
├── tests/                  # Automated validation tests
└── temporary_files/        # Generated credentials (gitignored)
```

## 🏗️ Infrastructure Components

### GCP Resources Created
- **Cloud Storage**: Multiple buckets with varying access controls
- **Compute Engine**: VMs with metadata service vulnerabilities
- **Cloud Functions**: Python functions with exploitable endpoints
- **IAM**: Service accounts with intentional misconfigurations
- **CloudAI Portal**: Web interface for advanced challenges

### Security Vulnerabilities Demonstrated
- Predictable resource naming patterns
- Overprivileged service accounts
- Exposed metadata endpoints
- Terraform state exposure
- Insecure cloud function configurations

## 🎮 Playing the Challenges

1. **Start with hints**: Check `hints/module1.md`, `hints/module2.md`, etc.
2. **Use provided tooling**: Validation scripts help verify progress
3. **Follow the progression**: Each module builds on previous concepts
4. **Check solutions**: Full walkthroughs available in `solution.md`

## 📚 Learning Objectives

- Cloud storage security best practices
- GCP IAM and service account security
- Metadata service attack vectors
- Infrastructure as Code (IaC) security
- Cloud function security considerations
- Progressive privilege escalation techniques

## ⚠️ Security Warnings

- **Educational use only** - contains intentional vulnerabilities
- Requires dedicated GCP project with Owner permissions  
- All credentials stored in `temporary_files/` (auto-gitignored)
- Always run cleanup script after workshop completion
- Do not use in shared or production environments

## 🤝 Contributing

This workshop is designed for security education. When contributing:
- Test full setup/teardown cycles
- Update hints and solutions for new challenges  
- Ensure all resources are properly tagged for cleanup
- Follow existing terraform patterns and naming conventions

## 📄 License

Licensed under GPL v3. See `LICENSE.md` for details. 