variable "region" {
  type        = string
  description = "Region"
  default     = "ru-1"
}
variable "project_name" {
  type        = string
  description = "Project name"
  default     = "services"
}
variable "cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "services-cluster"
}
variable "cluster_description" {
  type        = string
  description = "Cluster description"
  default     = "Services cluster"
}
variable "cluster_network_driver" {
  type        = string
  description = "Cluster network driver"
  default     = "calico"
}
variable "cluster_version" {
  type        = string
  description = "Cluster version"
  default     = "v1.34.3+k0s.0"
}
variable "node_group_name" {
  type        = string
  description = "Node group name"
  default     = "services-node-group"
}
variable "node_group_node_count" {
  type        = number
  description = "Node group node count"
  default     = 3
}

variable "home_dir" {
  type        = string
  description = "Home directory"
  default     = "/home/opusdv"
}
