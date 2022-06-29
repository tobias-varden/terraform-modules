variable "region" {
    type = string
}

variable "family" {
    type = string
}

variable "name" {
    type = string
}

variable "architecture" {
    type = string
    default = "x86_64"
}

variable "memory" {
    type = number
    default = 128
}

variable "environment" {
    type = string
    default = "Development"
}

variable "service_dependencies" {
    type = map(object({
        host = string
        port = number
    }))
    default = {}
}

variable "environment_variables" {
    type = map(string)
    default = {}
}

variable "managed_policy_arns" {
    type = list(string)
    default = []
}


variable "function_inline_policies" {
    type = map(string)
    default = {}
}

variable "vpc" {
    type = object({
        security_group_ids = list(string)
        subnets = list(object({id = string}))
    })
    default = {
        security_group_ids = []
        subnets = []
    }
}

variable "tags" {
    type = map(string)
}

variable "log_retention_in_days" {
    type = number
    default = 14
}

variable "container" {
    type = object({
        image_tag = string
    })
}

variable "enable_xray" {
    type = bool
    default = false
}

variable "timeout" {
    type = number
    default = 3
}

variable "parameters" {
    type = map(object({
        value = string
        is_secure = bool
    }))
    default = {}
}
