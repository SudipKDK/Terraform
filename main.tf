# network module
module "vpc" {
  source               = "./modules/vpc"
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = terraform.workspace

}

# database module
module "rds" {
  source               = "./modules/rds"
  environment          = terraform.workspace
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name
  db_password          = var.db_password
}


# compute module
module "compute" {
  source             = "./modules/compute"
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type      = var.instance_type
  environment        = terraform.workspace
  db_endpoint        = module.rds.rds_endpoint
}
