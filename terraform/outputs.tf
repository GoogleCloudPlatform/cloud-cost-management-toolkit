output "dataform_sa_email" {
  description = "The email of the dynamically created Dataform Service Account"
  value       = local.dataform_sa_email
}

output "dataform_git_public_deploy_key" {
  description = "MANDATORY WORKSPACE ACTION: Copy this public key string and paste it as a Read-Only 'Deploy Key' inside your GitHub repository settings to unblock dataform sync!"
  value       = var.enable_dataform_repo && var.dataform_git_remote_url != "" ? tls_private_key.dataform_git_key[0].public_key_openssh : null
}

output "billing_dataset_id" {
  description = "The BigQuery dataset ID holding open-source Dataform pipeline outputs"
  value       = local.gcp_billing_dataset_id
}

output "repository_id" {
  description = "The full resource name/ID of the created Dataform repository"
  value       = var.enable_dataform_repo ? module.dataform_oss[0].repository_id : ""
}
