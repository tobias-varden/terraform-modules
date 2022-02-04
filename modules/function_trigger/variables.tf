variable "region" {
    type = string
}

variable "name" {
    type = string
}

variable "environment" {
    type = string
    default = "Development"
}

variable "tags" {
    type = map(string)
}

variable "function" {
    type = object({
        arn = string
        function_name = string
    })
}

variable "schedule_expression" {
    type = string
}

variable "enabled" {
    type = bool
    default = false
}