// Test GCP VM

data "template_file" "gcp-init" {
  template = file("${path.module}/gcp-vm-config/gcp_bootstrap.sh")
  vars = {
    name     = "BU1-Analytics"
    password = var.ace_password
  }
/*   template = <<EOF
#!/bin/bash
sudo hostnamectl set-hostname "BU1-Analytics"
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo echo 'ubuntu:${var.ace_password}' | /usr/sbin/chpasswd
sudo /etc/init.d/ssh restart
EOF */
}

resource "google_compute_firewall" "gcp-comp-firewall" {
  name    = "gcp-comp-firewall"
  network = module.gcp_spoke_1.vpc.id 
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = [80, 443, 22]
  }
}

resource "google_compute_address" "gcp-spoke1-eip" {
  name         = "${var.gcp_spoke1_name}-eip"
  address_type = "EXTERNAL"
  region = var.gcp_spoke1_region
}

resource "google_compute_instance" "gcp-spoke1-ubu" {
  name         = "${var.gcp_spoke1_name}-ubu"
  machine_type = "n1-standard-1"
  zone         = "${var.gcp_spoke1_region}-b"
  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20200923"
    }
  }
  network_interface {
    network    = module.gcp_spoke_1.vpc.id
    subnetwork = module.gcp_spoke_1.vpc.subnets[0].name
    network_ip = "172.16.211.100"
    access_config {
      nat_ip = google_compute_address.gcp-spoke1-eip.address
    }
  }
  metadata = {
    ssh-keys = tls_private_key.avtx_key.public_key_openssh
  }
  metadata_startup_script = data.template_file.gcp-init.rendered
}

output "gcp_spoke1_ubu_public_ip" {
  value = google_compute_address.gcp-spoke1-eip.address
}

output "gcp_spoke1_ubu_private_ip" {
  value = google_compute_instance.gcp-spoke1-ubu.network_interface[0].network_ip
}
