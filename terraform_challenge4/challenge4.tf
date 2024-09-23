# Archive a single file.

data "archive_file" "main" {
  # https://cloud.google.com/functions/docs/writing/specifying-dependencies-python#packaging_local_dependencies
  type        = "zip"
  source_dir = "${path.module}/script"
  output_path = "${path.module}/files/main.zip"
}

resource "google_storage_bucket" "cloud-function-bucket" {
  name     = "cloud-function-bucket-challenge4"
  location = "US"
}

resource "google_storage_bucket_object" "gcs-function-file" {
  name   = "main.zip"
  bucket = google_storage_bucket.cloud-function-bucket.name
  source = data.archive_file.main.output_path
}

resource "google_cloudfunctions_function" "function" {
  name        = "challenge4-function"
  description = "This is a python function used for Challenge 4"
  runtime     = "python39"
  region       = var.region

  available_memory_mb   = 2048
  source_archive_bucket = google_storage_bucket.cloud-function-bucket.name
  source_archive_object = google_storage_bucket_object.gcs-function-file.name
  trigger_http          = true
  entry_point           = "hello_http"
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}