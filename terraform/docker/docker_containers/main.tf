terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

module "warpsql-volumes" {
  source = "../docker_volumes"
}

resource "docker_network" "private_network" {
  name   = "warpsql-network"
  driver = "bridge"
}


resource "docker_image" "warpsql-alpine" {
  name         = "samagragovernance/postgres:latest-pg15"
  keep_locally = true
}

resource "docker_image" "warpsql-barman" {
  name         = "ubcctlt/barman" # make a custom image
  keep_locally = true
}

resource "docker_container" "warpsql-alpine" {
  image = docker_image.warpsql-alpine.image_id
  name  = "warpsql"
  ports {
    internal = 5432
    external = 5432
  }
  networks_advanced {
    name    = docker_network.private_network.id
    aliases = ["pg"]
  }
  command = ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
  env     = ["POSTGRES_PASSWORD=warpsql"]
  volumes {
    container_path = "/etc/postgresql/postgresql.conf"
    host_path      = abspath("${path.module}/postgresql.conf")
    read_only      = true
  }
  volumes {
    container_path = "/docker-entrypoint-initdb.d/"
    host_path      = abspath("${path.module}/init/")
    # read_only = true
  }

  volumes {
    container_path = "/var/lib/postgresql"
    volume_name    = module.warpsql-volumes.volume-postgres.name
  }
}

resource "docker_container" "warpsql-barman" {
  image = docker_image.warpsql-barman.image_id
  name  = "warpsql-barman"
  networks_advanced {
    name = docker_network.private_network.id
  }
  env = [
    "DB_SUPERUSER=barman", "DB_SUPERUSER_PASSWORD=barman",
    "DB_REPLICATION_USER=streaming_barman",
    "DB_REPLICATION_PASSWORD=streaming_barman"
  ]
  volumes {
    container_path = "/etc/barman"
    host_path      = abspath("${path.module}/barman")
    read_only      = true
  }
  volumes {
    container_path = "/var/lib/barman"
    read_only      = false
    volume_name    = module.warpsql-volumes.volume-barman.name

  }

}


