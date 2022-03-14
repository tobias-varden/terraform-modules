data "aws_vpc" "this" {
  tags = {
    Name = var.vpc_tags.vpc_name
    Environment = var.vpc_tags.environment
  }
}

data "aws_subnets" "private_subnet_ids" {

  filter {
    name = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  tags = {
    Environment = var.vpc_tags.environment
    Kind = "private"
  }
}

data "aws_subnet" "private_subnets" {
    for_each = toset(data.aws_subnets.private_subnet_ids.ids)
    id = each.value
    vpc_id = data.aws_vpc.this.id
}

data "aws_subnets" "public_subnet_ids" {

  filter {
    name = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  tags = {
    Environment = var.vpc_tags.environment
    Kind = "public"
  }
}

data "aws_subnet" "public_subnets" {
    for_each = toset(data.aws_subnets.public_subnet_ids.ids)
    id = each.value
    vpc_id = data.aws_vpc.this.id
}

locals {
  public_subnets = values(data.aws_subnet.public_subnets)

  private_subnets = values(data.aws_subnet.private_subnets)
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.this.id
  filter {
    name = "group-name"
    values = ["default"]
  }
}