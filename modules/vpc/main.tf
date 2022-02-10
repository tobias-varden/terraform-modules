data "aws_vpc" "this" {
  tags = {
    Name = var.vpc_tags.vpc_name
    Environment = var.vpc_tags.environment
  }
}

data "aws_subnet_ids" "private_subnet_ids" {
  vpc_id = data.aws_vpc.this.id

  tags = {
    Environment = var.vpc_tags.environment
    Kind = "private"
  }
}

data "aws_subnet" "private_subnets" {
    for_each = data.aws_subnet_ids.private_subnet_ids.ids
    id = each.value
    vpc_id = data.aws_vpc.this.id
}

data "aws_subnet_ids" "public_subnet_ids" {
  vpc_id = data.aws_vpc.this.id

  tags = {
    Environment = var.vpc_tags.environment
    Kind = "public"
  }
}

data "aws_subnet" "public_subnets" {
    for_each = data.aws_subnet_ids.public_subnet_ids.ids
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