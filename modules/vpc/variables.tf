variable "vpc_tags" {
    type = object({
        vpc_name = string
        environment = string
    })
}