# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A PRIVATE CLUSTER IN GOOGLE CLOUD PLATFORM
# ---------------------------------------------------------------------------------------------------------------------

module "gke_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "github.com/gruntwork-io/terraform-google-gke.git//modules/gke-cluster?ref=v0.2.0"
  source = "../../modules/gke-cluster"
}

module "gke_service_account" {
  source = "../../modules/gke-cluster"
}

module "vpc_network" {
  source  = "../../modules/gke-cluster"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NODE POOL
# ---------------------------------------------------------------------------------------------------------------------

resource "google_container_node_pool" "node_pool" {
  provider = google-beta

  name     = "private-pool"
  project  = var.project
  location = var.location
  cluster  = module.gke_cluster.cluster_name
  

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
      private-app-pool = "web-app"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private_vpc,
      "private-pool-example",
    ]

    disk_size_gb = "30"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.service_account_email

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
  cluster     = module.gke_cluster.cluster_name
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
      module.vpc_network.private_vpc,
      "private-db-pool",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.service_account_email

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
  cluster     = module.gke_cluster.cluster_name
  node_count  = 1

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-2"

    labels = {
      private-nfs-pool = "nfs-drive"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private_vpc,
      "private-nfs-pool",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.service_account_email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE REDIS SINGLETON NODE POOL
# ---------------------------------------------------------------------------------------------------------------------
resource "google_container_node_pool" "redis_single_pool" {
  provider    = google-beta
  name        = "redis-single-node-pool"
  location    = var.location
  project     = var.project
  cluster     = module.gke_cluster.cluster_name
  node_count  = 1

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-1"

    labels = {
      private-redis-single-pool = "redis-single"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private_vpc,
      "private-redis-single-pool",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.service_account_email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE REDIS CLUSTER NODE POOL
# ---------------------------------------------------------------------------------------------------------------------
#resource "google_container_node_pool" "redis_pool" {
#  provider    = google-beta
#  name        = "redis-node-pool"
#  project     = var.project
#  location    = var.location
#  cluster     = module.gke_cluster.cluster_name
#  node_count  = 6
#
#  node_config {
#    image_type   = "COS"
#    machine_type = "n1-standard-1"
#
#    labels = {
#      private-redis-pool = "redis-cluster"
#    }
#
#    # Add a private tag to the instances. See the network access tier table for full details:
#    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
#    tags = [
#      module.vpc_network.private_vpc,
#      "private-redis-pool",
#    ]
#
#    disk_size_gb = "10"
#    disk_type    = "pd-standard"
#    preemptible  = false
#
#    service_account = module.gke_service_account.service_account_email
#
#    oauth_scopes = [
#      "https://www.googleapis.com/auth/cloud-platform",
#    ]
#  }
#}

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




