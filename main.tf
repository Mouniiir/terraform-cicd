data "aws_availability_zones" "available" {}

locals {
  name   = "example"
  region = "eu-west-1"
  cluster_name = "example-poc"
  vpc_cidr = "10.206.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    owner = "example"
    Environment = "poc"
    terraform-managed : true
  }
  private_subnets_tags = {
    Type = "Private"
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"

  }
  public_subnets_tags = {
    Type = "Public"
    "kubernetes.io/role/internal-elb" = 1

  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = local.name
  cidr = local.vpc_cidr

  azs                 = local.azs
  private_subnets     = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets      = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  database_subnets    = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 8)]
  enable_nat_gateway = true
  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = local.tags
  private_subnet_tags = local.private_subnets_tags
  public_subnet_tags =  local.public_subnets_tags
  
  enable_vpn_gateway = true
  customer_gateways = {
    hq  = {
      bgp_asn     = 65112
      ip_address  = "0.0.0.0"
      device_name  = "hq"
    },
  }

}
module "vpn-gateway" {
  source  = "terraform-aws-modules/vpn-gateway/aws"
  version = "3.7.1"
  vpn_connection_static_routes_only         = true
  vpn_connection_static_routes_destinations = ["172.21.0.0/24"]

  vpn_gateway_id      = module.vpc.vgw_id
  customer_gateway_id = module.vpc.cgw_ids[0]

  vpc_id                       = module.vpc.vpc_id
  vpc_subnet_route_table_ids   = module.vpc.private_route_table_ids
  vpc_subnet_route_table_count = 3

}