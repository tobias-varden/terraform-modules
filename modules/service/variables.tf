variable "family" {
    type = string
}

variable "name" {
    type = string
}

variable "execution_role_arn" {
    type = string
}

variable "task_role_arn" {
    type = string
    default = ""
}

variable "ecs_cluster" {
    type = object({
        name = string
        id = string
    })
}

variable "region" {
    type = string
}

variable "desired_count" {
    type = number
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

variable "log_retention_in_days" {
    type = number
}

variable "environment" {
    type = string
    default = "Development"
}

variable "security_groups" {
    type = list(string)
    default = []
}

variable "managed_policy_arns" {
    type = list(string)
    default = []
}

variable "task_inline_policies" {
    type = map(string)
    default = {}
}

variable "lb_target_group_arn" {
    type = string
    default = ""
}

variable "lb_security_group_id" {
    type = string
    default = ""
}

variable "discovery_namespace" {
    type = object({
        id = string
        name = string
    })
}

variable "vpc" {
    type = object({
        id = string,
        cidr_block = string
    })
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

variable "service_container" {
    type = object({
        cpu = number
        memory = number
        image_tag = string
        port = number
    })
}

variable "xray_agent" {
    type = object({
        host = string
        port = number
    })
    default = null
}

variable "environment_overrides" {
    type = map(object({
        cpu = number
        memory = number
        desired_count = number
    }))
    default = {}
}

variable "austoscaling_settings" {
    type = object({
        max_allowed_services = number
        memory_threshold = number
        cpu_threshold = number
    })
    default = {
        max_allowed_services = 0
        memory_threshold = 80
        cpu_threshold = 60
    }
}

variable "parameters" {
    type = map(object({
        value = string
        is_secure = bool
    }))
    default = {}
}

variable "healthCheck" {
    type = object({
        command = list(string)
        interval = number
        retries = number
        timeout = number
        startPeriod = number
    })
    default = null
}