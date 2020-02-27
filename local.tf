locals {
  asg_tags = null_resource.tags_as_list_of_maps.*.triggers

  # Followed recommendation http://67bricks.com/blog/?p=85
  # to workaround terraform not supporting short circut evaluation
  cluster_security_group_id = coalesce(
    join("", aws_security_group.cluster.*.id),
    var.cluster_security_group_id,
  )

  cluster_iam_role_name = coalesce(
    join("", aws_iam_role.cluster.*.name),
    var.cluster_iam_role_name,
    "aws-eks"
  )
  cluster_iam_role_arn = coalesce(
    join("", aws_iam_role.cluster.*.arn),
    join("", data.aws_iam_role.custom_cluster_iam_role.*.arn),
    "aws-eks"
  )

  worker_security_group_id = coalesce(
    join("", aws_security_group.workers.*.id),
    var.worker_security_group_id,
  )
  default_iam_role_id = concat(aws_iam_role.workers.*.id, [""])[0]
  kubeconfig_name     = var.kubeconfig_name == "" ? "eks_${var.cluster_name}" : var.kubeconfig_name

  worker_group_count                       = length(var.worker_groups)
  worker_group_launch_template_count       = var.worker_groups_launch_template_count > 0 ? var.worker_groups_launch_template_count : length(var.worker_groups_launch_template)
  worker_group_launch_template_mixed_count = length(var.worker_groups_launch_template_mixed)

  workers_group_defaults_defaults = {
    name                          = "count.index"              # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    tags                          = []                         # A list of map defining extra tags to be applied to the worker group ASG.
    ami_id                        = data.aws_ami.eks_worker.id # AMI ID for the eks workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI.
    asg_desired_capacity          = "1"                        # Desired worker capacity in the autoscaling group.
    asg_max_size                  = "3"                        # Maximum worker capacity in the autoscaling group.
    asg_min_size                  = "1"                        # Minimum worker capacity in the autoscaling group.
    asg_force_delete              = false                      # Enable forced deletion for the autoscaling group.
    instance_type                 = "m4.large"                 # Size of the workers instances.
    spot_price                    = ""                         # Cost of spot instance.
    placement_tenancy             = ""                         # The tenancy of the instance. Valid values are "default" or "dedicated".
    root_volume_size              = "100"                      # root volume size of workers instances.
    root_volume_type              = "gp2"                      # root volume type of workers instances, can be 'standard', 'gp2', or 'io1'
    root_iops                     = "0"                        # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    key_name                      = ""                         # The key name that should be used for the instances in the autoscaling group
    pre_userdata                  = ""                         # userdata to pre-append to the default userdata.
    bootstrap_extra_args          = ""                         # Extra arguments passed to the bootstrap.sh script from the EKS AMI.
    additional_userdata           = ""                         # userdata to append to the default userdata.
    ebs_optimized                 = true                       # sets whether to use ebs optimization on supported types.
    enable_monitoring             = true                       # Enables/disables detailed monitoring.
    public_ip                     = false                      # Associate a public ip address with a worker
    kubelet_extra_args            = ""                         # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    subnets                       = var.subnets                # A list of subnets to place the worker nodes in. i.e. ["subnet-123", "subnet-456", "subnet-789"]
    autoscaling_enabled           = false                      # Sets whether policy and matching tags will be added to allow autoscaling.
    additional_security_group_ids = []                         # A list of additional security group ids to include in worker launch config
    protect_from_scale_in         = false                      # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.
    iam_instance_profile_name     = ""                         # A custom IAM instance profile name. Used when manage_worker_iam_resources is set to false. Incompatible with iam_role_id.
    iam_role_id                   = local.default_iam_role_id  # A custom IAM role id. Incompatible with iam_instance_profile_name.
    suspended_processes           = ["AZRebalance"]            # A list of processes to suspend. i.e. ["AZRebalance", "HealthCheck", "ReplaceUnhealthy"]
    target_group_arns             = []                         # A list of ALB target group ARNs to be associated to the ASG
    enabled_metrics               = []                         # A list of metrics to be collected i.e. ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity"]
    placement_group               = ""                         # The name of the placement group into which to launch the instances, if any.
    service_linked_role_arn       = ""                         # Arn of custom service linked role that Auto Scaling group will use. Useful when you have encrypted EBS
    termination_policies          = []                         # A list of policies to decide how the instances in the auto scale group should be terminated.
    # Settings for launch templates
    root_block_device_name            = data.aws_ami.eks_worker.root_device_name # Root device name for workers. If non is provided, will assume default AMI was used.
    root_kms_key_id                   = ""                                       # The KMS key to use when encrypting the root storage device
    launch_template_version           = "$Latest"                                # The lastest version of the launch template to use in the autoscaling group
    launch_template_placement_tenancy = "default"                                # The placement tenancy for instances
    launch_template_placement_group   = ""                                       # The name of the placement group into which to launch the instances, if any.
    root_encrypted                    = ""                                       # Whether the volume should be encrypted or not
    eni_delete                        = true                                     # Delete the ENI on termination (if set to false you will have to manually delete before destroying)
    cpu_credits                       = "standard"                               # T2/T3 unlimited mode, can be 'standard' or 'unlimited'. Used 'standard' mode as default to avoid paying higher costs
    # Settings for launch templates with mixed instances policy
    override_instance_types                  = ["m5.large", "m5a.large", "m5d.large", "m5ad.large"] # A list of override instance types for mixed instances policy
    on_demand_allocation_strategy            = "prioritized"                                        # Strategy to use when launching on-demand instances. Valid values: prioritized.
    on_demand_base_capacity                  = "0"                                                  # Absolute minimum amount of desired capacity that must be fulfilled by on-demand instances
    on_demand_percentage_above_base_capacity = "0"                                                  # Percentage split between on-demand and Spot instances above the base on-demand capacity
    spot_allocation_strategy                 = "lowest-price"                                       # The only valid value is lowest-price, which is also the default value. The Auto Scaling group selects the cheapest Spot pools and evenly allocates your Spot capacity across the number of Spot pools that you specify.
    spot_instance_pools                      = 10                                                   # "Number of Spot pools per availability zone to allocate capacity. EC2 Auto Scaling selects the cheapest Spot pools and evenly allocates Spot capacity across the number of Spot pools that you specify."
    spot_max_price                           = ""                                                   # Maximum price per unit hour that the user is willing to pay for the Spot instances. Default is the on-demand price
  }

  workers_group_defaults = merge(
    local.workers_group_defaults_defaults,
    var.workers_group_defaults,
  )

  ebs_optimized = {
    "c1.medium"    = false
    "c1.xlarge"    = true
    "c3.large"     = false
    "c3.xlarge"    = true
    "c3.2xlarge"   = true
    "c3.4xlarge"   = true
    "c3.8xlarge"   = false
    "c4.large"     = true
    "c4.xlarge"    = true
    "c4.2xlarge"   = true
    "c4.4xlarge"   = true
    "c4.8xlarge"   = true
    "c5.large"     = true
    "c5.xlarge"    = true
    "c5.2xlarge"   = true
    "c5.4xlarge"   = true
    "c5.9xlarge"   = true
    "c5.18xlarge"  = true
    "c5d.large"    = true
    "c5d.xlarge"   = true
    "c5d.2xlarge"  = true
    "c5d.4xlarge"  = true
    "c5d.9xlarge"  = true
    "c5d.18xlarge" = true
    "cc2.8xlarge"  = false
    "cr1.8xlarge"  = false
    "d2.xlarge"    = true
    "d2.2xlarge"   = true
    "d2.4xlarge"   = true
    "d2.8xlarge"   = true
    "f1.2xlarge"   = true
    "f1.4xlarge"   = true
    "f1.16xlarge"  = true
    "g2.2xlarge"   = true
    "g2.8xlarge"   = false
    "g3s.xlarge"   = true
    "g3.4xlarge"   = true
    "g3.8xlarge"   = true
    "g3.16xlarge"  = true
    "h1.2xlarge"   = true
    "h1.4xlarge"   = true
    "h1.8xlarge"   = true
    "h1.16xlarge"  = true
    "hs1.8xlarge"  = false
    "i2.xlarge"    = true
    "i2.2xlarge"   = true
    "i2.4xlarge"   = true
    "i2.8xlarge"   = false
    "i3.large"     = true
    "i3.xlarge"    = true
    "i3.2xlarge"   = true
    "i3.4xlarge"   = true
    "i3.8xlarge"   = true
    "i3.16xlarge"  = true
    "i3.metal"     = true
    "m1.small"     = false
    "m1.medium"    = false
    "m1.large"     = true
    "m1.xlarge"    = true
    "m2.xlarge"    = false
    "m2.2xlarge"   = true
    "m2.4xlarge"   = true
    "m3.medium"    = false
    "m3.large"     = false
    "m3.xlarge"    = true
    "m3.2xlarge"   = true
    "m4.large"     = true
    "m4.xlarge"    = true
    "m4.2xlarge"   = true
    "m4.4xlarge"   = true
    "m4.10xlarge"  = true
    "m4.16xlarge"  = true
    "m5a.large"    = true
    "m5a.xlarge"   = true
    "m5a.2xlarge"  = true
    "m5a.4xlarge"  = true
    "m5a.12xlarge" = true
    "m5a.24xlarge" = true
    "m5.large"     = true
    "m5.xlarge"    = true
    "m5.2xlarge"   = true
    "m5.4xlarge"   = true
    "m5.12xlarge"  = true
    "m5.24xlarge"  = true
    "m5d.large"    = true
    "m5d.xlarge"   = true
    "m5d.2xlarge"  = true
    "m5d.4xlarge"  = true
    "m5d.12xlarge" = true
    "m5d.24xlarge" = true
    "p2.xlarge"    = true
    "p2.8xlarge"   = true
    "p2.16xlarge"  = true
    "p3.2xlarge"   = true
    "p3.8xlarge"   = true
    "p3.16xlarge"  = true
    "r3.large"     = false
    "r3.xlarge"    = true
    "r3.2xlarge"   = true
    "r3.4xlarge"   = true
    "r3.8xlarge"   = false
    "r4.large"     = true
    "r4.xlarge"    = true
    "r4.2xlarge"   = true
    "r4.4xlarge"   = true
    "r4.8xlarge"   = true
    "r4.16xlarge"  = true
    "r5a.large"    = true
    "r5a.xlarge"   = true
    "r5a.2xlarge"  = true
    "r5a.4xlarge"  = true
    "r5a.12xlarge" = true
    "r5a.24xlarge" = true
    "r5.large"     = true
    "r5.xlarge"    = true
    "r5.2xlarge"   = true
    "r5.4xlarge"   = true
    "r5.12xlarge"  = true
    "r5.24xlarge"  = true
    "t1.micro"     = false
    "t2.nano"      = false
    "t2.micro"     = false
    "t2.small"     = false
    "t2.medium"    = false
    "t2.large"     = false
    "t2.xlarge"    = false
    "t2.2xlarge"   = false
    "t3a.nano"     = true
    "t3a.micro"    = true
    "t3a.small"    = true
    "t3a.medium"   = true
    "t3a.large"    = true
    "t3a.xlarge"   = true
    "t3a.2xlarge"  = true
    "t3.nano"      = true
    "t3.micro"     = true
    "t3.small"     = true
    "t3.medium"    = true
    "t3.large"     = true
    "t3.xlarge"    = true
    "t3.2xlarge"   = true
    "x1.16xlarge"  = true
    "x1.32xlarge"  = true
    "x1e.xlarge"   = true
    "x1e.2xlarge"  = true
    "x1e.4xlarge"  = true
    "x1e.8xlarge"  = true
    "x1e.16xlarge" = true
    "x1e.32xlarge" = true
  }
}
