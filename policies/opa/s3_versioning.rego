package terraform.s3_versioning

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.actions[_] == "create"
    resource.change.after.tags.Environment == "production"
    versioning := input.resource_changes[_]
    versioning.type == "aws_s3_bucket_versioning"
    versioning.change.after.bucket == resource.change.after.id
    versioning.change.after.versioning_configuration[_].status != "Enabled"
    msg := sprintf(
        "Production S3 bucket %s must have versioning enabled",
        [resource.address]
    )
}

warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not any_lifecycle_exists(input.resource_changes, resource.change.after.id)
    msg := sprintf(
        "S3 bucket %s should have lifecycle rules for cost management",
        [resource.address]
    )
}

any_lifecycle_exists(changes, bucket_id) if {
    change := changes[_]
    change.type == "aws_s3_bucket_lifecycle_configuration"
    change.change.after.bucket == bucket_id
}
