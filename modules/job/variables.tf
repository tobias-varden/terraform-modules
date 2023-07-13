variable "region" {
    type = string
}

variable "family" {
    type = string
}

variable "name" {
    type = string
}

variable "execution_role" {
    type = object({
        arn = string
    })
}

variable "command" {
    type = list(string)
}

variable "default_parameters" {
    type = map(string)
    default = {}
}

variable "compute_environment" {
    type = object({
        arn = string
    })
}

variable "container" {
    type = object({
        cpu = number
        memory = number
        image_tag = string
    })
}

variable "xray_agent" {
    type = object({
        host = string
        port = number
    })
    default = null
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


variable "job_inline_policies" {
    type = map(string)
    default = {}
}

variable "environment" {
    type = string
    default = "Development"
}

variable "subnets" {
    type = list(object({
        id = string
    }))
}

variable "tags" {
    type = map(string)
}

variable "log_retention_in_days" {
    type = number
    default = 14
}

variable "parameters" {
    type = map(object({
        value = string
        is_secure = bool
    }))
    default = {}
}

variable "retries" {
    type = number
    default = 1
}