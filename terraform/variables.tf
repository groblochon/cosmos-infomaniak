variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "Infomaniak cloud region"
  type        = string
  default     = "dc3-a"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kubernetes_version" {
  description = "Kubernetes version to use"
  type        = string
  default     = "1.28"
}

variable "node_pool_size" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 3
  validation {
    condition     = var.node_pool_size >= 1 && var.node_pool_size <= 100
    error_message = "Node pool size must be between 1 and 100."
  }
}

variable "node_flavor" {
  description = "Flavor/machine type for cluster nodes"
  type        = string
  default     = "standard"
}

variable "enable_monitoring" {
  description = "Enable monitoring and logging for the cluster"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for node pools"
  type        = bool
  default     = false
}

variable "autoscaling_min_nodes" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
  validation {
    condition     = var.autoscaling_min_nodes >= 1
    error_message = "Minimum nodes must be at least 1."
  }
}

variable "autoscaling_max_nodes" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
  validation {
    condition     = var.autoscaling_max_nodes >= var.autoscaling_min_nodes
    error_message = "Maximum nodes must be greater than or equal to minimum nodes."
  }
}

variable "network_name" {
  description = "Name of the network to use or create"
  type        = string
  default     = null
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "storage_enabled" {
  description = "Enable persistent storage"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Default storage size in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.storage_size >= 1 && var.storage_size <= 10000
    error_message = "Storage size must be between 1 and 10000 GB."
  }
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

variable "database_enabled" {
  description = "Deploy managed database service"
  type        = bool
  default     = false
}

variable "database_type" {
  description = "Type of database (mysql, postgresql, mariadb)"
  type        = string
  default     = "postgresql"
  validation {
    condition     = contains(["mysql", "postgresql", "mariadb"], var.database_type)
    error_message = "Database type must be one of: mysql, postgresql, mariadb."
  }
}

variable "database_version" {
  description = "Database version"
  type        = string
  default     = "14"
}

variable "ingress_enabled" {
  description = "Enable ingress controller"
  type        = bool
  default     = true
}

variable "ingress_class" {
  description = "Ingress controller class"
  type        = string
  default     = "nginx"
}

variable "cert_manager_enabled" {
  description = "Enable cert-manager for SSL/TLS certificates"
  type        = bool
  default     = true
}

variable "dns_provider" {
  description = "DNS provider for cert-manager (letsencrypt-prod, letsencrypt-staging)"
  type        = string
  default     = "letsencrypt-prod"
}

variable "resource_quota_enabled" {
  description = "Enable resource quotas"
  type        = bool
  default     = true
}

variable "cpu_limit" {
  description = "CPU limit per namespace"
  type        = string
  default     = "10"
}

variable "memory_limit" {
  description = "Memory limit per namespace in Gi"
  type        = string
  default     = "20Gi"
}

variable "rbac_enabled" {
  description = "Enable RBAC (Role-Based Access Control)"
  type        = bool
  default     = true
}

variable "pod_security_policy" {
  description = "Enable Pod Security Policy"
  type        = bool
  default     = true
}

variable "network_policy_enabled" {
  description = "Enable network policies"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Logging level (debug, info, warn, error)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "custom_labels" {
  description = "Additional custom labels for resources"
  type        = map(string)
  default     = {}
}

variable "custom_annotations" {
  description = "Additional custom annotations for resources"
  type        = map(string)
  default     = {}
}
