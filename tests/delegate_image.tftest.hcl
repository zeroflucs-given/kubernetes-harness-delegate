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
