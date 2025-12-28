terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# OpenStack Provider Configuration
provider "openstack" {
  auth_url    = var.openstack_auth_url
  user_name   = var.openstack_username
  password    = var.openstack_password
  tenant_name = var.openstack_tenant_name
  region      = var.openstack_region
}

# AWS Provider Configuration for S3
provider "aws" {
  region = var.aws_region

  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  skip_credentials_validation = var.aws_skip_credentials_validation
  skip_region_validation      = var.aws_skip_region_validation
}

# OpenStack Network Resources
resource "openstack_networking_network_v2" "main_network" {
  name           = var.network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "main_subnet" {
  name            = var.subnet_name
  network_id      = openstack_networking_network_v2.main_network.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "main_router" {
  name                = var.router_name
  external_gateway_info {
    network_id = data.openstack_networking_network_v2.external_network.id
  }
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.main_router.id
  subnet_id = openstack_networking_subnet_v2.main_subnet.id
}

# OpenStack Security Group
resource "openstack_networking_secgroup_v2" "main_secgroup" {
  name                 = var.security_group_name
  description          = "Security group for Cosmos infrastructure"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "ingress_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  port_range_min    = 80
  port_range_max    = 80
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  port_range_min    = 443
  port_range_max    = 443
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  port_range_min    = 22
  port_range_max    = 22
  protocol          = "tcp"
  remote_ip_prefix  = var.ssh_cidr
  security_group_id = openstack_networking_secgroup_v2.main_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "egress_all" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = ""
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main_secgroup.id
}

# OpenStack Instances
resource "openstack_compute_instance_v2" "app_servers" {
  count           = var.app_server_count
  name            = "${var.instance_name_prefix}-${count.index + 1}"
  image_name      = var.openstack_image_name
  flavor_name     = var.openstack_flavor_name
  key_pair        = var.openstack_key_pair
  security_groups = [openstack_networking_secgroup_v2.main_secgroup.name]

  network {
    uuid = openstack_networking_network_v2.main_network.id
  }

  metadata = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [openstack_networking_router_interface_v2.router_interface]
}

# S3 Bucket for Cosmos data storage
resource "aws_s3_bucket" "cosmos_data" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "cosmos_data" {
  bucket = aws_s3_bucket.cosmos_data.id

  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cosmos_data" {
  bucket = aws_s3_bucket.cosmos_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.s3_encryption_algorithm
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "cosmos_data" {
  bucket = aws_s3_bucket.cosmos_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "cosmos_data" {
  count  = var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.cosmos_data.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.s3_transition_days_to_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_transition_days_to_glacier
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_expiration_days
    }
  }
}

# S3 Bucket Logging
resource "aws_s3_bucket_logging" "cosmos_data" {
  count          = var.s3_logging_enabled ? 1 : 0
  bucket         = aws_s3_bucket.cosmos_data.id
  target_bucket  = aws_s3_bucket.cosmos_logs[0].id
  target_prefix  = "logs/"
}

# S3 Bucket for logs
resource "aws_s3_bucket" "cosmos_logs" {
  count  = var.s3_logging_enabled ? 1 : 0
  bucket = "${var.s3_bucket_name}-logs"

  tags = {
    Name        = "${var.s3_bucket_name}-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# S3 Bucket Access Control for logs bucket
resource "aws_s3_bucket_acl" "cosmos_logs" {
  count  = var.s3_logging_enabled ? 1 : 0
  bucket = aws_s3_bucket.cosmos_logs[0].id
  acl    = "log-delivery-write"
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "cosmos_data" {
  count  = var.s3_bucket_policy_enabled ? 1 : 0
  bucket = aws_s3_bucket.cosmos_data.id
  policy = data.aws_iam_policy_document.cosmos_data_policy[0].json
}

# Data source for S3 bucket policy
data "aws_iam_policy_document" "cosmos_data_policy" {
  count = var.s3_bucket_policy_enabled ? 1 : 0

  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.cosmos_data.arn,
      "${aws_s3_bucket.cosmos_data.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Outputs
output "openstack_network_id" {
  value       = openstack_networking_network_v2.main_network.id
  description = "OpenStack network ID"
}

output "openstack_subnet_id" {
  value       = openstack_networking_subnet_v2.main_subnet.id
  description = "OpenStack subnet ID"
}

output "openstack_router_id" {
  value       = openstack_networking_router_v2.main_router.id
  description = "OpenStack router ID"
}

output "instance_ips" {
  value       = [for instance in openstack_compute_instance_v2.app_servers : instance.access_ip_v4]
  description = "Private IP addresses of OpenStack instances"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.cosmos_data.id
  description = "Name of the S3 bucket"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.cosmos_data.arn
  description = "ARN of the S3 bucket"
}

output "s3_bucket_region" {
  value       = aws_s3_bucket.cosmos_data.region
  description = "Region of the S3 bucket"
}
