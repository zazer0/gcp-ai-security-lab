# Module 1: Enumeration and Discovery
# Creates modeldata-dev and modeldata-prod buckets with intentional misconfigurations

resource "google_storage_bucket" "modeldata-dev" {
  name          = "modeldata-dev-${var.project_id}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "modeldata-prod" {
  name          = "modeldata-prod-${var.project_id}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
}

resource "google_service_account" "bucket-service-account" {
  account_id   = "bucket-service-account"
  display_name = "Bucket Service Account"
  description  = "Service account for accessing model storage buckets"
}

# Grant dev bucket access
resource "google_storage_bucket_iam_member" "dev-bucket-access" {
  bucket = google_storage_bucket.modeldata-dev.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.bucket-service-account.email}"
}

# Grant prod bucket access (the vulnerability)
resource "google_storage_bucket_iam_member" "prod-bucket-access" {
  bucket = google_storage_bucket.modeldata-prod.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.bucket-service-account.email}"
}

# Create service account key
resource "google_service_account_key" "bucket-sa-key" {
  service_account_id = google_service_account.bucket-service-account.name
}

# Custom role for remediation
resource "google_project_iam_custom_role" "dev-bucket-access" {
  role_id     = "DevBucketAccess"
  title       = "Dev Bucket Access"
  description = "Access to development bucket only"
  permissions = [
    "storage.buckets.get",
    "storage.objects.get",
    "storage.objects.list"
  ]
}