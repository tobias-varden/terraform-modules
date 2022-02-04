variable "ecs_cluster_id" {
    type = string
}

variable "region" {
    type = string
}

variable "vpc" {
    type = object({
        id = string,
        cidr_block = string
    })
}

variable "subnets" {
    type = list
}

variable "assign_public_ip" {
    type = bool
}

variable "tags" {
    type = map(string)
}

variable "environment" {
    type = string
    default = "Development"
}

variable "discovery_namespace" {
    type = object({
        id = string
        name = string
    })
}

variable "execution_role_arn" {
    type = string
}

variable "family" {
    type = string
}

variable "tag" {
    type = string
}