resource "helm_release" "delegate" {
  name             = var.delegate_name
  repository       = var.helm_repository
  chart            = "harness-delegate-ng"
  namespace        = var.namespace
  create_namespace = var.create_namespace

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

locals {
  values = yamlencode({
    accountId           = var.account_id
    managerEndpoint     = var.manager_endpoint
    namespace           = var.namespace
    delegateName        = var.delegate_name
    delegateDockerImage = var.delegate_image
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
    upgrader = {
      enabled         = var.upgrader_enabled
      imagePullSecret = var.upgrader_image_pull_secret
    }
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