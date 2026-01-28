provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "web_vpc" {
  name                    = "${local.resource_prefix}-vpc"
  auto_create_subnetworks = false
}

# Subnet 1
resource "google_compute_subnetwork" "web_subnet" {
  name          = "${local.resource_prefix}-subnet1"
  ip_cidr_range = "172.16.10.0/24"
  region        = var.region
  network       = google_compute_network.web_vpc.id
}

# Subnet 2
resource "google_compute_subnetwork" "web_subnet2" {
  name          = "${local.resource_prefix}-subnet2"
  ip_cidr_range = "172.16.11.0/24"
  region        = var.region
  network       = google_compute_network.web_vpc.id
}

# Firewall rules (open 22 + 80 to world, 0.0.0.0/0)
resource "google_compute_firewall" "web_fw" {
  name    = "${local.resource_prefix}-fw"
  network = google_compute_network.web_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Compute Engine VM (like aws_instance)
resource "google_compute_instance" "web_host" {
  name         = "${local.resource_prefix}-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = var.gcp_image
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web_subnet.id
    access_config {} # gives external IP
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    systemctl start apache2
    systemctl enable apache2
    # Insecure demo: hardcoding fake "GCP keys"
    export GOOGLE_CLIENT_EMAIL="demo-service-account@my-demo-project.iam.gserviceaccount.com"
    export GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\\nMIIEvAIBADANBgkqh...\\n-----END PRIVATE KEY-----\\n"
    echo "<h1>Deployed via Terraform (GCP)</h1>" > /var/www/html/index.html
  EOT

  tags = ["web"]

  labels = {
    yor_trace = "5dc2f2f8-940c-49ec-8abb-2227ba981fb5"
  }
}


resource "google_storage_bucket" "flowbucket" {
  name          = "${local.resource_prefix}-flowlogs"
  location      = var.region
  force_destroy = true
  labels = {
    yor_trace = "a70a1585-13b8-41c2-b278-3aa967c49605"
  }
}


# Outputs
output "vm_external_ip" {
  value = google_compute_instance.web_host.network_interface[0].access_config[0].nat_ip
}
