mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  account_id       = "account"
  delegate_token   = "token"
  delegate_name    = "release"
  manager_endpoint = "https://app.harness.io/gratis"
  delegate_image   = "harness/delegate:1.0.0"
  values           = "delegateName: delegate"
}

run "running_image" {
  command = plan

  override_data {
    target = data.kubernetes_resources.delegate[0]
    values = {
      objects = [{
        spec = { template = { spec = { containers = [{ name = "delegate", image = "harness/delegate:2.0.0" }] } } }
      }]
    }
  }

  assert {
    condition     = data.kubernetes_resources.delegate[0].field_selector == "metadata.name=delegate"
    error_message = "wrong deployment name"
  }

  assert {
    condition     = yamldecode(output.values).delegateDockerImage == "harness/delegate:2.0.0"
    error_message = "running image not used"
  }
}

run "first_install" {
  command = plan

  override_data {
    target = data.kubernetes_resources.delegate[0]
    values = { objects = [] }
  }

  assert {
    condition     = yamldecode(output.values).delegateDockerImage == "harness/delegate:1.0.0"
    error_message = "delegate_image not used"
  }
}

run "upgrader_disabled" {
  command = plan

  variables {
    upgrader_enabled = false
  }

  assert {
    condition     = yamldecode(output.values).delegateDockerImage == "harness/delegate:1.0.0"
    error_message = "delegate_image not used"
  }
}

run "timeout" {
  command = plan

  variables {
    timeout = 900
  }

  assert {
    condition     = helm_release.delegate.timeout == 900
    error_message = "timeout not used"
  }
}

run "upgrader_mirror" {
  command = plan

  variables {
    upgrader_image           = "docker.io/harness/upgrader:latest"
    upgrader_registry_mirror = "public.ecr.aws/harness"
  }

  assert {
    condition     = yamldecode(output.values).upgrader.upgraderDockerImage == "docker.io/harness/upgrader:latest"
    error_message = "upgrader_image not used"
  }

  assert {
    condition     = yamldecode(output.values).upgrader.registryMirror == "public.ecr.aws/harness"
    error_message = "upgrader_registry_mirror not used"
  }
}

run "upgrader_defaults" {
  command = plan

  assert {
    condition     = !contains(keys(yamldecode(output.values).upgrader), "upgraderDockerImage") && !contains(keys(yamldecode(output.values).upgrader), "registryMirror")
    error_message = "chart defaults overridden"
  }
}
