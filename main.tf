resource "helm_release" "delegate" {
  name             = var.delegate_name
  repository       = var.helm_repository
  chart            = "harness-delegate-ng"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  timeout          = var.timeout

  values = [data.utils_deep_merge_yaml.values.output]

  # ref https://github.com/hashicorp/terraform-provider-helm/pull/480
  set_sensitive = [
    {
      name  = "delegateToken"
      value = var.delegate_token
      type  = "string"
    }
  ]
}

# Reuse the running image so applies don't undo the upgrader
data "kubernetes_resources" "delegate" {
  count = var.upgrader_enabled ? 1 : 0

  api_version    = "apps/v1"
  kind           = "Deployment"
  namespace      = var.namespace
  field_selector = "metadata.name=${local.deployment_name}"
}

locals {
  deployment_name = try(yamldecode(var.values).delegateName, var.delegate_name)
  running_image = try(one([
    for c in data.kubernetes_resources.delegate[0].objects[0].spec.template.spec.containers : c.image if c.name == "delegate"
  ]), null)
  delegate_image = coalesce(local.running_image, var.delegate_image)

  values = yamlencode({
    accountId           = var.account_id
    managerEndpoint     = var.manager_endpoint
    namespace           = var.namespace
    delegateName        = var.delegate_name
    delegateDockerImage = local.delegate_image
    replicas            = var.replicas
    upgrader            = { enabled = var.upgrader_enabled }
    nextGen             = var.next_gen
    proxyUser           = var.proxy_user
    proxyPassword       = var.proxy_password
    proxyHost           = var.proxy_host
    proxyPort           = var.proxy_port
    proxyScheme         = var.proxy_scheme
    noProxy             = var.no_proxy
    initScript          = var.init_script
    deployMode          = var.deploy_mode
    mTLS                = { secretName = var.mtls_secret_name }

    # Service account configuration
    serviceAccount = {
      create      = var.service_account.create
      name        = var.service_account.name
      annotations = var.service_account.annotations
    }

    # Image pull secret for the delegate image
    imagePullSecret = var.image_pull_secret

    # Image pull secret for the upgrader image (separate field per values.yaml)
    upgrader = merge(
      {
        enabled         = var.upgrader_enabled
        imagePullSecret = var.upgrader_image_pull_secret
      },
      var.upgrader_image != "" ? { upgraderDockerImage = var.upgrader_image } : {},
      var.upgrader_registry_mirror != "" ? { registryMirror = var.upgrader_registry_mirror } : {},
    )
  })
}

data "utils_deep_merge_yaml" "values" {
  input = compact([
    local.values,
    var.values
  ])
}

output "values" {
  value = data.utils_deep_merge_yaml.values.output
}