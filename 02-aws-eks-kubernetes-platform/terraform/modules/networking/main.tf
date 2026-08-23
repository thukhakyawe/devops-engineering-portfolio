
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vpc"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = zipmap(
    var.availability_zones,
    var.public_subnet_cidrs
  )

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                     = "${var.name}-public-${each.key}"
      Tier                     = "public"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = zipmap(
    var.availability_zones,
    var.private_subnet_cidrs
  )

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(
    var.tags,
    {
      Name                              = "${var.name}-private-${each.key}"
      Tier                              = "private"
      "kubernetes.io/role/internal-elb" = "1"
      "karpenter.sh/discovery"          = var.name
    }
  )
}

resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-eip-${each.key}"
    }
  )
}

resource "aws_nat_gateway" "this" {
  for_each = toset(var.availability_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [
    aws_internet_gateway.this
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-${each.key}"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-rt-${each.key}"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id = each.value.id

  route_table_id = aws_route_table.private[
    each.key
  ].id
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name}-eks-nodes"
  description = "Security group for EKS worker nodes."
  vpc_id      = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name                     = "${var.name}-eks-nodes"
      "karpenter.sh/discovery" = var.name
    }
  )
}