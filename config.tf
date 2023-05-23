terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token     = "<токен>"
  cloud_id  = "<cloud_id>"
  folder_id = "<folder_id>"
  zone      = "ru-central1-a"
}

variable "image-id" {
  type = string
}
 
resource "yandex_compute_instance" "terraform-vm-1" {
  name = "vm-1"
  platform_id = "standard-v1"
  zone = "ru-central1-a"
 
  resources {
    cores  = 2
    memory = 2
	core_fraction = 5
  }
 
  boot_disk {
    initialize_params {
      image_id = var.image-id
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.terraform-subnet.id
    nat       = true
  }
 
  metadata = {
    ssh-keys = "ubuntu:${file("~/meta.txt")}"
  }
}

resource "yandex_compute_instance" "terraform-vm-2" {
  name = "vm-2"
  platform_id = "standard-v1"
  zone = "ru-central1-a"
 
  resources {
    cores  = 2
    memory = 2
	core_fraction = 5
  }
 
  boot_disk {
    initialize_params {
      image_id = var.image-id
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.terraform-subnet.id
    nat       = true
  }
 
  metadata = {
    ssh-keys = "ubuntu:${file("~/meta.txt")}"
  }
}

resource "yandex_lb_target_group" "terraform-target-group" {
  name      = "target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.terraform-subnet.id
    address   = yandex_compute_instance.terraform-vm-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.terraform-subnet.id
    address   = yandex_compute_instance.terraform-vm-2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "terraform-load-balancer" {
  name = "network-load-balancer"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.terraform-target-group.id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}

resource "yandex_compute_instance" "terraform-vm-comp" {
  name = "vm-comp"
  platform_id = "standard-v1"
  zone = "ru-central1-a"
 
  resources {
    cores  = 4
    memory = 8
	core_fraction = 20
  }
 
  boot_disk {
    initialize_params {
      image_id = var.image-id
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.terraform-subnet.id
    nat       = true
  }
 
  metadata = {
    ssh-keys = "ubuntu:${file("~/meta.txt")}"
  }
}

resource "yandex_vpc_network" "terraform-network-1" {
  name = "network-1"
}
 
resource "yandex_vpc_subnet" "terraform-subnet" {
  name           = "subnet-1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.terraform-network-1.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}
 
resource "yandex_mdb_postgresql_cluster" "postgres-1" {
  name        = "postgres-1"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.terraform-network-1.id
 
  config {
    version = 12
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-hdd"
      disk_size          = 16
    }
    postgresql_config = {
      max_connections                   = 395
      enable_parallel_hash              = true
      vacuum_cleanup_index_scale_factor = 0.2
      autovacuum_vacuum_scale_factor    = 0.34
      default_transaction_isolation     = "TRANSACTION_ISOLATION_READ_COMMITTED"
      shared_preload_libraries          = "SHARED_PRELOAD_LIBRARIES_AUTO_EXPLAIN,SHARED_PRELOAD_LIBRARIES_PG_HINT_PLAN"
    }
  }
 
  database {
    name  = "postgres-1"
    owner = "my-name"
  }
 
  user {
    name       = "my-name"
    password   = "Test1234"
    conn_limit = 50
    permission {
      database_name = "postgres-1"
    }
    settings = {
      default_transaction_isolation = "read committed"
      log_min_duration_statement    = 5000
    }
  }
 
  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.terraform-subnet.id
  }
}