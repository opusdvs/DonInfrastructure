variable "cluster_name" {
  type = string
  description = "The name of the cluster"
}

variable "cluster_description" {
  type = string
  description = "The description of the cluster"
}

variable "cluster_network_driver" {
  type = string
  description = "The network driver of the cluster"
}

variable "cluster_version" {
  type = string
  description = "The version of the cluster"
}

variable "node_group_name" {
  type = list(string)
  description = "The name of the node group"
}

variable "network_driver" {
  type = string
  description = "The network driver of the cluster"
}

variable "cluster_preset_id" {
  type = string
  description = "The preset id of the cluster"
}

variable "project_id" {
  type = string
  description = "The project id of the cluster"
}

variable "node_group_cpu" {
  type = number
  description = "The cpu of the node group"
}

variable "node_group_preset_id" {
  type = string
  description = "The preset id of the node group"
}

variable "node_group_node_count" {
  type = number
  description = "The node count of the node group"
}