terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-b"

}

resource "yandex_compute_instance" "vm" {
  count = 2
  name ="vm${count.index}"
  platform_id = "standard-v1"
  boot_disk {
    initialize_params {
      image_id = "fd87j6d92jlrbjqbl32q" # ubuntu
      size = 8
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat = true
  }

  resources {
    core_fraction  = 5
    cores = 2
    memory = 2
  }

  metadata = { user-data = "${file("user.yml")}" }

}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_lb_target_group" "demo-1" {
  name = "demo-1"

  dynamic "target" {
    for_each = yandex_compute_instance.vm[*].network_interface.0.ip_address
    content {
      address = target.value
      subnet_id = yandex_vpc_subnet.subnet-1.id
    }
  }
}

resource "yandex_lb_network_load_balancer" "lb-1" {
  name = "lb-1"
  deletion_protection = "false"
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.demo-1.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

output "lb-ip" {
  value = yandex_lb_network_load_balancer.lb-1.listener
}

output "vm_ips" {
  value = tomap({
    for name, vm in yandex_compute_instance.vm : name => vm.network_interface.0.ip_address
  })

}