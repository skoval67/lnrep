# разворачиваем окружение в YC
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone      = "ru-central1-a"
  folder_id = var.YC_KEYS.folder_id
}

# из-за ограничения в две сети на облако, предварительно импортируем имеющуюся сеть
# terraform import yandex_vpc_network.network1 network1_id
resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network1.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "subnet-3" {
  name           = "subnet3"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network1.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "route-to-internet"
  network_id = yandex_vpc_network.network1.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_compute_instance_group" "some-ig" {
  name               = "some-ig-with-balancer"
  folder_id          = var.YC_KEYS.folder_id
  service_account_id = var.YC_KEYS.service_account_id
  instance_template {
    platform_id = "standard-v1"
    resources {
      memory        = 6
      cores         = 4
      core_fraction = 20
    }

    scheduling_policy {
      preemptible = true
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = var.image_id
        size     = 15
      }
    }

    network_interface {
      network_id = yandex_vpc_network.network1.id
      subnet_ids = ["${yandex_vpc_subnet.subnet-1.id}", "${yandex_vpc_subnet.subnet-2.id}"]
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a", "ru-central1-b"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  # load_balancer {
  #   target_group_name        = "target-group"
  #   target_group_description = "load balancer target group"
  # }
}

resource "yandex_lb_target_group" "lb_tg" {
  name = "lbtg-web"

  target {
    subnet_id  = yandex_vpc_subnet.subnet-3.id
    address = yandex_compute_instance.vm-1.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "nlb-web" {
  name = "nlb-web"

  listener {
    name        = "listener1"
    port        = 8080
    target_port = 8080
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name        = "listener2"
    port        = 3000
    target_port = 3000
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name        = "listener3"
    port        = 6443
    target_port = 6443
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.lb_tg.id
    healthcheck {
      name = "health-check"
      tcp_options {
        port = 22
      }
    }
  }
}

resource "yandex_compute_instance" "vm-1" {
  name                      = "adminwks"
  platform_id               = "standard-v1"
  allow_stopping_for_update = true

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 4
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = var.adminwks_image_id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-3.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

}

resource "yandex_dns_zone" "external_zone" {
  name        = "externalzone"
  description = "externalzone"
  zone        = var.site_name
  public      = true
}

resource "yandex_dns_recordset" "rs1" {
  zone_id = yandex_dns_zone.external_zone.id
  name    = "${var.nlb_name}.${var.site_name}"
  type    = "A"
  ttl     = 200
  data    = [flatten(flatten(yandex_lb_network_load_balancer.nlb-web.listener)[0].external_address_spec)[0].address]
}

resource "yandex_dns_recordset" "rs2" {
  zone_id = yandex_dns_zone.external_zone.id
  name    = "www.${var.site_name}"
  type    = "CNAME"
  ttl     = 200
  data    = ["${yandex_dns_recordset.rs1.name}"]
}

resource "yandex_dns_recordset" "rs3" {
  zone_id = yandex_dns_zone.external_zone.id
  name    = "@"
  type    = "CNAME"
  ttl     = 200
  data    = ["${yandex_dns_recordset.rs1.name}"]
}

resource "yandex_dns_recordset" "rs4" {
  zone_id = yandex_dns_zone.external_zone.id
  name    = "admin.${var.site_name}"
  type    = "A"
  ttl     = 200
  data    = [yandex_compute_instance.vm-1.network_interface.0.nat_ip_address]
}

resource "yandex_dns_zone" "local_zone" {
  name             = "private-zone"
  description      = "private zone"
  zone             = "local.net."
  public           = false
  private_networks = [yandex_vpc_network.network1.id]
}

resource "yandex_dns_recordset" "priv_rs1" {
  zone_id = yandex_dns_zone.local_zone.id
  name    = "registry.local.net."
  type    = "A"
  ttl     = 200
  data    = [yandex_compute_instance.vm-1.network_interface.0.ip_address]
}

output "instance_group_ip_addresses" {
  value = yandex_compute_instance_group.some-ig.instances[*].network_interface[0].ip_address
}

output "admin_server_ip_address" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}