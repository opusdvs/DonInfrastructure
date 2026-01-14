variable "twc_token" {
  type        = string
  description = "Timeweb Cloud API token"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "dev-cluster"
}

variable "cluster_description" {
  type        = string
  description = "Cluster description"
  default     = "Dev cluster"
}

variable "cluster_network_driver" {
  type        = string
  description = "Cluster network driver"
  default     = "calico"
}

variable "cluster_version" {
  type        = string
  description = "Cluster version"
  default     = "v1.34.2+k0s.0"
}

variable "node_group_name" {
  type        = string
  description = "Node group name"
  default     = "node-group"
}

variable "node_group_description" {
  type        = string
  description = "Node group description"
  default     = "Node group"
}

variable "node_group_node_count" {
  type        = number
  description = "Node group node count"
  default     = 3
}