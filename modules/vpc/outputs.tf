output "vpc" {
    value = data.aws_vpc.this
}

output "private_subnet_ids" {
    value = data.aws_subnet_ids.private_subnet_ids
}

output "private_subnets" {
    value = local.private_subnets
}

output "public_subnet_ids" {
    value = data.aws_subnet_ids.public_subnet_ids
}

output "public_subnets" {
    value = local.public_subnets
}

output "default_security_group" {
    value = data.aws_security_group.default
}