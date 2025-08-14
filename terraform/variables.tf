variable "region" {
  default = "us-east1"
}

variable "zone" {
  default = "b"
}

variable "project_id" {}

variable "project_number" {}

# Flag configuration for module gating
variable "flag1_value" {
  description = "Flag value to unlock Module 2 (System Status). This flag is found in the dev bucket during Module 1."
  type        = string
  default     = "flag{found-the-lazy-dev}"
}

variable "flag2_value" {
  description = "Flag value to unlock Module 3 (Monitoring). This flag is found in the terraform state file during Module 2."
  type        = string
  default     = "flag{found-the-secret-infrastructure}"
}
