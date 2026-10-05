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

# Machine health for every OCI instance lifecycle state the module maps
# (locals_health.tf): one health_<state> run each. Every run replaces the
# instance so the overridden state is what a fresh read returns. Mocks and
# variables are those of machine.tftest.hcl.

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

run "health_pending" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "PROVISIONING"
    }
  }

  assert {
    condition     = output.health.state == "pending" && !output.health.healthy && output.health.reasons == tolist(["InstanceProvisioning"])
    error_message = "A PROVISIONING instance is pending."
  }
  assert {
    condition     = output.health.message == "instance is PROVISIONING"
    error_message = "health.message must name the OCI state."
  }
}

run "health_starting" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "STARTING"
    }
  }

  assert {
    condition     = output.health.state == "pending" && !output.health.healthy && output.health.reasons == tolist(["InstanceStarting"])
    error_message = "A STARTING instance is pending."
  }
  assert {
    condition     = output.health.message == "instance is STARTING"
    error_message = "health.message must name the OCI state."
  }
}

run "health_running" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "RUNNING"
    }
  }

  assert {
    condition     = output.health.state == "running" && output.health.healthy && length(output.health.reasons) == 0
    error_message = "A RUNNING instance is running and healthy."
  }
  assert {
    condition     = output.health.message == "instance is RUNNING"
    error_message = "health.message must name the OCI state."
  }
}

run "health_moving" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "MOVING"
    }
  }

  assert {
    condition     = output.health.state == "running" && output.health.healthy && length(output.health.reasons) == 0
    error_message = "A MOVING instance is running and healthy."
  }
  assert {
    condition     = output.health.message == "instance is MOVING"
    error_message = "health.message must name the OCI state."
  }
}

run "health_unknown" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "CREATING_IMAGE"
    }
  }

  assert {
    condition     = output.health.state == "unknown" && !output.health.healthy && output.health.reasons == tolist(["InstanceCreatingImage"])
    error_message = "A CREATING_IMAGE instance is unknown."
  }
  assert {
    condition     = output.health.message == "instance is CREATING_IMAGE"
    error_message = "health.message must name the OCI state."
  }
}

run "health_stopping" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "STOPPING"
    }
  }

  assert {
    condition     = output.health.state == "stopped" && !output.health.healthy && output.health.reasons == tolist(["InstanceStopping"])
    error_message = "A STOPPING instance is stopped."
  }
  assert {
    condition     = output.health.message == "instance is STOPPING"
    error_message = "health.message must name the OCI state."
  }
}

run "health_stopped" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "STOPPED"
    }
  }

  assert {
    condition     = output.health.state == "stopped" && !output.health.healthy && output.health.reasons == tolist(["InstanceStopped"])
    error_message = "A STOPPED instance is stopped."
  }
  assert {
    condition     = output.health.message == "instance is STOPPED"
    error_message = "health.message must name the OCI state."
  }
}

run "health_terminating" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "TERMINATING"
    }
  }

  assert {
    condition     = output.health.state == "terminated" && !output.health.healthy && output.health.reasons == tolist(["InstanceNotFound"])
    error_message = "A TERMINATING instance is terminated."
  }
  assert {
    condition     = output.health.message == "instance is TERMINATING"
    error_message = "health.message must name the OCI state."
  }
}

run "health_terminated" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "TERMINATED"
    }
  }

  assert {
    condition     = output.health.state == "terminated" && !output.health.healthy && output.health.reasons == tolist(["InstanceNotFound"])
    error_message = "A TERMINATED instance is terminated."
  }
  assert {
    condition     = output.health.message == "instance is TERMINATED"
    error_message = "health.message must name the OCI state."
  }
}

run "health_unmapped" {
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = ""
      state      = "UPDATING_FIRMWARE"
    }
  }

  assert {
    condition     = output.health.state == "unknown" && !output.health.healthy && output.health.reasons == tolist(["UnknownState"])
    error_message = "An instance in a state the module does not know is unknown, never healthy."
  }
  assert {
    condition     = output.health.message == "instance is UPDATING_FIRMWARE"
    error_message = "health.message must name the OCI state."
  }
}
