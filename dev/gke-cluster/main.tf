# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A GKE PRIVATE CLUSTER IN GOOGLE CLOUD PLATFORM
# This is an example of how to use the gke-cluster module to deploy a private Kubernetes cluster in GCP
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # The modules used in this example have been updated with 0.12 syntax, additionally we depend on a bug fixed in
  # version 0.12.7.
  required_version = ">= 0.12.7"
}

# ---------------------------------------------------------------------------------------------------------------------
# PREPARE PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  # provider version deprecated in version 1.0
  # version = "~> 2.15"
  project = var.project
  region  = var.region
}

provider "google-beta" {
  # provider version deprecated in version 1.0
  # version = "~> 2.15"
  project = var.project
  region  = var.region
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A PRIVATE CLUSTER IN GOOGLE CLOUD PLATFORM
# ---------------------------------------------------------------------------------------------------------------------

module "gke_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-cluster?ref=v0.2.0"
  #source = "../../modules/gke-cluster"
  source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-cluster?ref=v0.10.0"	

  name = var.cluster_name

  project  = var.project
  location = var.location
  network  = module.vpc_network.network
  
  # We're deploying the cluster in the 'public' subnetwork to allow outbound internet access
  # See the network access tier table for full details:
  # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
  subnetwork = module.vpc_network.public_subnetwork

  # When creating a private cluster, the 'master_ipv4_cidr_block' has to be defined and the size must be /28
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  # This setting will make the cluster private
  enable_private_nodes = "true"

  # To make testing easier, we keep the public endpoint available. In production, we highly recommend restricting access to only within the network boundary, requiring your users to use a bastion host or VPN.
  disable_public_endpoint = "false"

  # With a private cluster, it is highly recommended to restrict access to the cluster master
  # However, for testing purposes we will allow all inbound traffic.
  master_authorized_networks_config = [
    {
      cidr_blocks = [
        {
          cidr_block   = "0.0.0.0/0"
          display_name = "all-for-testing"
        },
      ]
    },
  ]

  cluster_secondary_range_name = module.vpc_network.public_subnetwork_secondary_range_name

  enable_vertical_pod_autoscaling = var.enable_vertical_pod_autoscaling
  
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CUSTOM SERVICE ACCOUNT TO USE WITH THE GKE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
module "gke_service_account" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-service-account?ref=v0.2.0"
  #source = "../../modules/gke-service-account"
  source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-service-account?ref=v0.10.0"

  name                    = var.cluster_service_account_name
  project                 = var.project
  description             = var.cluster_service_account_description
  service_account_roles   = var.service_account_roles
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NETWORK TO DEPLOY THE CLUSTER TO
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_network" {
  source = "github.com/gruntwork-io/terraform-google-network.git//modules/vpc-network?ref=v0.9.0"

  name_prefix = "${var.cluster_name}-network-${random_string.suffix.result}"
  project     = var.project
  region      = var.region

  cidr_block           = var.vpc_cidr_block
  secondary_cidr_block = var.vpc_secondary_cidr_block
}

#------------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL RULE TO ALLOW ACCESS FOR ELASTICSEARTCH
#------------------------------------------------------------------------------------------------------------------------
resource "google_compute_firewall" "elastic-fw-rule" {
  name    = "elasticsearch-firewall-rule"
  network = module.vpc_network.network

  allow {
    protocol = "tcp"
    ports    = ["9443"]
  }

  source_ranges = [var.master_ipv4_cidr_block]
  target_tags   = []
}

# Use a random suffix to prevent overlap in network names
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NODE POOL
# ---------------------------------------------------------------------------------------------------------------------

resource "google_container_node_pool" "node_pool" {
  provider = google-beta

  name     = "app-pool"
  project  = var.project
  location = var.location
  cluster  = module.gke_cluster.name
  

  initial_node_count = "1"

  autoscaling {
    min_node_count = "1"
    max_node_count = "5"
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-2"

    labels = {
      "private-app-pool" = "web-app"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private,
      "private-pool-magento",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "database_pool" {
  provider    = google-beta
  name        = "db-node-pool"
  location    = var.location
  project     = var.project
  cluster     = module.gke_cluster.name
  node_count  = 1

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-2"

    labels = {
      private-db-pool = "mysql-db"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private,
      "private-db-pool",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "google_container_node_pool" "nfs_pool" {
  provider    = google-beta
  name        = "nfs-node-pool"
  location    = var.location
  project     = var.project
  cluster     = module.gke_cluster.name
  node_count  = 1

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-4"

    labels = {
      private-nfs-pool = "nfs-drive"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private,
      "private-nfs-pool",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "google_container_node_pool" "elastic_pool" {
  provider    = google-beta
  name        = "elastic-node-pool"
  location    = var.location
  project     = var.project
  cluster     = module.gke_cluster.name
  node_count  = 1

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-2"

    labels = {
      private-elastic-pool = "elastic-drive"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private,
      "private-elastic-pool",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PERESISTENT DISK 
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_disk" "default" {
  name        = "nfs-disk"
  description = "To hold Magento peristent data i.e. media assets and logs"
  type        = "pd-ssd"
  zone        = var.location
  size        = 10
  labels      = {
    environment = "dev"
  }
  physical_block_size_bytes = 4096
}




