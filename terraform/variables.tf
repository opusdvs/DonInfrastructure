variable "twc_token" {
  type        = string
  description = "Timeweb Cloud API token"
}
variable "region" {
  type        = string
  description = "Region"
}
variable "project_name" {
  type        = string
  description = "Project name"
}
variable "cluster_name" {
  type        = string
  description = "Cluster name"
}
variable "cluster_description" {
  type        = string
  description = "Cluster description"
}
variable "cluster_network_driver" {
  type        = string
  description = "Cluster network driver"
}
variable "cluster_version" {
  type        = string
  description = "Cluster version"
}
variable "node_group_name" {
  type        = string
  description = "Node group name"
}
variable "node_group_node_count" {
  type        = number
  description = "Node group node count"
}