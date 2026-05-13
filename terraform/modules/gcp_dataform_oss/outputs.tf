# Copyright 2026 Google LLC
# Outputs for Dataform OSS child module

output "repository_id" {
  description = "The full resource ID string of the provisioned Dataform repository container"
  value       = google_dataform_repository.dataform_repository.id
}
