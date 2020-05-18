output "cluster_endpoint" {
  description = "The IP address of the cluster master."
  sensitive   = true
  value       = module.gke_cluster.endpoint
}

output "client_certificate" {
  description = "Public certificate used by clients to authenticate to the cluster endpoint."
  value       = module.gke_cluster.client_certificate
}

output "client_key" {
  description = "Private key used by clients to authenticate to the cluster endpoint."
  sensitive   = true
  value       = module.gke_cluster.client_key
}

output "cluster_ca_certificate" {
  description = "The public certificate that is the root of trust for the cluster."
  sensitive   = true
  value       = module.gke_cluster.cluster_ca_certificate
}

output "cluster_name" {
  description = "Module cluster name."
  value       = module.gke_cluster.name
}

output "private_vpc" {
  description = "Private network"
  value       = module.vpc_network.private
}

output "service_account_email" {
  # This may seem redundant with the `name` input, but it serves an important
  # purpose. Terraform won't establish a dependency graph without this to interpolate on.
  description = "The email address of the custom service account."
  value       = module.gke_service_account.email
}


