# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Every variable validation of the machine role fails the plan with its own
# message: one invalid_<variable> run each (CONVENTIONS.md section 14). The
# preconditions are in machine.tftest.hcl. Mocks and variables are those of
# machine.tftest.hcl.

mock_provider "oci" {
  mock_resource "oci_core_instance" {
    defaults = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      region     = "iad"
      state      = "RUNNING"
    }
  }
}

variables {
  captf_contract = "v1alpha1"
  captf_cluster  = { name = "demo", namespace = "team-a" }
  captf_object   = { kind = "TerraformMachine", name = "demo-md-0-abcde", namespace = "team-a" }
  captf_cluster_outputs = {
    schema                  = "captf.io/oci-cluster/v1"
    region                  = "us-ashburn-1"
    compartment_id          = "ocid1.compartment.oc1..aaaaaaaacluster"
    vcn_id                  = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
    control_plane_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane"
    worker_subnet_id        = "ocid1.subnet.oc1.iad.aaaaaaaaworkers"
    control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"
    worker_nsg_id           = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"
    failure_domains = {
      "US-ASHBURN-AD-1" = { availability_domain = "Uocm:US-ASHBURN-AD-1" }
      "US-ASHBURN-AD-2" = { availability_domain = "Uocm:US-ASHBURN-AD-2" }
      "US-ASHBURN-AD-3" = { availability_domain = "Uocm:US-ASHBURN-AD-3" }
    }
    node_defined_tags = {}
    api = {
      host                     = "10.0.0.10"
      port                     = 6443
      network_load_balancer_id = "ocid1.networkloadbalancer.oc1.iad.aaaaaaaaapi"
      kube_apiserver           = { backend_set_name = "kube-apiserver", port = 6443 }
    }
  }
  captf_tags = {
    "captf.io/cluster"    = "demo"
    "captf.io/namespace"  = "team-a"
    "captf.io/kind"       = "TerraformMachine"
    "captf.io/name"       = "demo-md-0-abcde"
    "captf.io/managed-by" = "captf"
    "captf.io/template"   = "demo-md-0"
  }
  machine_name = "demo-md-0-xyz12"
  # base64 of "#cloud-config\nruncmd: [echo hello]\n"
  bootstrap_data     = "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvXQo="
  bootstrap_format   = "cloud-config"
  failure_domain     = null
  kubernetes_version = "v1.34.1"
  control_plane      = false

  image_id = "ocid1.image.oc1.iad.aaaaaaaanode"
}

run "invalid_captf_contract" {
  command = plan

  variables {
    captf_contract = "v1alpha2"
  }

  expect_failures = [var.captf_contract]
}

run "invalid_bootstrap_format" {
  command = plan

  variables {
    bootstrap_format = "shell"
  }

  expect_failures = [var.bootstrap_format]
}

run "invalid_additional_tags_count" {
  command = plan

  variables {
    additional_tags = { a = "1", b = "2", c = "3", d = "4", e = "5" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_additional_tags_key" {
  command = plan

  variables {
    additional_tags = { "cost center" = "42" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_additional_tags_reserved" {
  command = plan

  variables {
    additional_tags = { "Captf_IO/name" = "other" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_boot_volume_kms_key_id" {
  command = plan

  variables {
    boot_volume_kms_key_id = "ocid1.vault.oc1.iad.aaaaaaaavault"
  }

  expect_failures = [var.boot_volume_kms_key_id]
}

run "invalid_boot_volume_size_gib" {
  command = plan

  variables {
    boot_volume_size_gib = 40
  }

  expect_failures = [var.boot_volume_size_gib]
}

run "invalid_external_cluster_exports" {
  command = plan

  variables {
    external_cluster_exports = { region = "us-ashburn-1" }
  }

  expect_failures = [var.external_cluster_exports]
}

run "invalid_ignore_defined_tags" {
  command = plan

  variables {
    ignore_defined_tags = ["Oracle-Tags"]
  }

  expect_failures = [var.ignore_defined_tags]
}

run "invalid_image_id" {
  command = plan

  variables {
    image_id = null
  }

  expect_failures = [var.image_id]
}

run "invalid_memory_gib" {
  command = plan

  variables {
    memory_gib = 0
  }

  expect_failures = [var.memory_gib]
}

run "invalid_additional_nsg_ids" {
  command = plan

  variables {
    additional_nsg_ids = ["sg-123"]
  }

  expect_failures = [var.additional_nsg_ids]
}

run "invalid_ocpus" {
  command = plan

  variables {
    ocpus = 0
  }

  expect_failures = [var.ocpus]
}

run "invalid_shape" {
  command = plan

  variables {
    shape = "t3.large"
  }

  expect_failures = [var.shape]
}

run "invalid_ssh_authorized_keys" {
  command = plan

  variables {
    ssh_authorized_keys = ["AAAAC3NzaC1lZDI1NTE5"]
  }

  expect_failures = [var.ssh_authorized_keys]
}

run "invalid_subnet_id" {
  command = plan

  variables {
    subnet_id = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
  }

  expect_failures = [var.subnet_id]
}
