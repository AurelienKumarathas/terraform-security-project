package terraform.required_tags

required_tags := ["Environment", "Owner", "CostCenter"]

deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    resource.change.after.tags != null
    missing := required_tags[_]
    not resource.change.after.tags[missing]
    msg := sprintf("Resource %s (%s) is missing required tag: %s", [resource.address, resource.type, missing])
}

warn contains msg if {
    resource := input.resource_changes[_]
    resource.change.after.tags.Environment != null
    valid_environments := {"production", "staging", "development"}
    env := resource.change.after.tags.Environment
    not valid_environments[env]
    msg := sprintf("Resource %s has invalid Environment tag: %s", [resource.address, env])
}
