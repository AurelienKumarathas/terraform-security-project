package terraform.ec2_instance_types

# Allowed instance families for production
allowed_production_families := ["t3", "m5", "c5", "r5"]

# Deny t2 instances in production
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    resource.change.actions[_] == "create"

    # Check if production
    resource.change.after.tags.Environment == "production"

    # Get instance type
    instance_type := resource.change.after.instance_type

    # Check if it's a t2 instance
    startswith(instance_type, "t2.")

    msg := sprintf(
        "Production EC2 instance %s cannot use t2 family (got: %s). Use t3 or larger.",
        [resource.address, instance_type]
    )
}

# Warn about small instances in production
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    resource.change.after.tags.Environment == "production"

    instance_type := resource.change.after.instance_type
    contains(instance_type, ".micro")

    msg := sprintf(
        "Production instance %s uses micro size (%s). Consider larger for reliability.",
        [resource.address, instance_type]
    )
}