output "vpc" {
    value = data.aws_vpc.this
}

output "private_subnet_ids" {
    value = data.aws_subnets.private_subnet_ids.ids
}

output "private_subnets" {
    value = local.private_subnets
}

output "public_subnet_ids" {
    value = data.aws_subnets.public_subnet_ids.ids
}

output "public_subnets" {
    value = local.public_subnets
}

output "default_security_group" {
    value = data.aws_security_group.default
}