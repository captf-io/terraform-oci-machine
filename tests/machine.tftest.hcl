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

# Unit tests of the machine role with a mocked OCI provider: no tenancy is
# contacted. Run from the role directory: `terraform test` or `tofu test`
# (`make unit-test` runs both). captf_cluster_outputs is what the cluster
# role exports for a three-AD region with a module-owned API load balancer.

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

run "happy_path" {
  assert {
    condition     = output.provider_id == "oci://${oci_core_instance.node_instance[0].id}"
    error_message = "provider_id must be oci://<instance OCID>, as the OCI cloud controller manager writes it."
  }
  assert {
    condition     = output.addresses == [{ type = "InternalIP", address = "10.0.0.23" }]
    error_message = "A private instance has its private IP as InternalIP and no ExternalIP."
  }
  assert {
    condition     = output.failure_domain == "US-ASHBURN-AD-3"
    error_message = "Without a request the failure domain is sorted(names)[sha256(machine_name) mod n]: US-ASHBURN-AD-3 for demo-md-0-xyz12."
  }
  assert {
    condition     = output.interruptible == false
    error_message = "An on-demand instance is not interruptible."
  }
  assert {
    condition     = output.health.state == "running" && output.health.healthy && output.health.message == "instance is RUNNING" && length(output.health.reasons) == 0
    error_message = "A RUNNING instance is running and healthy."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].display_name == "demo-md-0-xyz12" && oci_core_instance.node_instance[0].availability_domain == "Uocm:US-ASHBURN-AD-3" && local.fault_domain == null
    error_message = "The instance is named after the Machine and placed in the failure domain's availability domain; OCI picks the fault domain."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].compartment_id == "ocid1.compartment.oc1..aaaaaaaacluster" && oci_core_instance.node_instance[0].shape == "VM.Standard.E5.Flex"
    error_message = "The instance goes in the cluster's compartment on the default shape."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].shape_config[0].ocpus == 2 && oci_core_instance.node_instance[0].shape_config[0].memory_in_gbs == 16
    error_message = "The default flexible shape has 2 OCPUs and 16 GiB, as the image's capacity label says."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].source_details[0].source_id == "ocid1.image.oc1.iad.aaaaaaaanode" && oci_core_instance.node_instance[0].source_details[0].source_type == "image" && oci_core_instance.node_instance[0].source_details[0].boot_volume_size_in_gbs == "100"
    error_message = "The instance boots image_id on a 100 GiB boot volume."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].create_vnic_details[0].subnet_id == "ocid1.subnet.oc1.iad.aaaaaaaaworkers" && oci_core_instance.node_instance[0].create_vnic_details[0].nsg_ids == toset(["ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"])
    error_message = "A worker joins the worker subnet and NSG."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].create_vnic_details[0].assign_public_ip == "false"
    error_message = "No public IP by default (the provider defaults to one)."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].instance_options[0].are_legacy_imds_endpoints_disabled && oci_core_instance.node_instance[0].is_pv_encryption_in_transit_enabled
    error_message = "Legacy instance metadata is off and in-transit encryption on by default."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].preserve_boot_volume == false && length(oci_core_instance.node_instance[0].preemptible_instance_config) == 0
    error_message = "The boot volume goes with the instance, which is not preemptible by default."
  }
  assert {
    condition     = !contains(keys(nonsensitive(oci_core_instance.node_instance[0].metadata)), "ssh_authorized_keys")
    error_message = "No SSH keys by default."
  }
  assert {
    condition     = length(oci_network_load_balancer_backend.api_backends) == 0
    error_message = "A worker registers in no backend set."
  }
}

# Must follow happy_path directly: OpenTofu 1.12 reports an unknown condition
# for outputs of an earlier, non-adjacent run. Mocks never plan a
# replacement, so this proves only that nothing in the configuration churns;
# provider normalisation is DESIGN.md "Unverified" 7.
run "reapply_is_stable" {
  variables {
    previous_provider_id = run.happy_path.provider_id
  }

  assert {
    condition     = output.provider_id == var.previous_provider_id
    error_message = "A second identical apply must keep the instance."
  }
}

run "tags_on_taggable_resources" {
  variables {
    additional_tags = { CostCenter = "42" }
  }

  assert {
    condition = alltrue([for t in [
      oci_core_instance.node_instance[0].freeform_tags,
      oci_core_instance.node_instance[0].create_vnic_details[0].freeform_tags,
      ] : t == tomap({
        "CostCenter"          = "42"
        "captf_io/cluster"    = "demo"
        "captf_io/namespace"  = "team-a"
        "captf_io/kind"       = "TerraformMachine"
        "captf_io/name"       = "demo-md-0-abcde"
        "captf_io/managed-by" = "captf"
        "captf_io/template"   = "demo-md-0"
    })])
    error_message = "The instance and its VNIC must carry the mapped captf tags and additional_tags."
  }
}

run "worker_has_no_backend" {
  variables {
    control_plane = false
  }

  assert {
    condition     = length(oci_network_load_balancer_backend.api_backends) == 0
    error_message = "A worker must not register in the API load balancer."
  }
}

run "control_plane_registers_backend" {
  variables {
    control_plane = true
    machine_name  = "demo-control-plane-abcde"
  }

  assert {
    condition     = keys(oci_network_load_balancer_backend.api_backends) == ["kube_apiserver"]
    error_message = "A control-plane machine registers in every backend set of the API load balancer."
  }
  assert {
    condition     = oci_network_load_balancer_backend.api_backends["kube_apiserver"].target_id == oci_core_instance.node_instance[0].id && oci_network_load_balancer_backend.api_backends["kube_apiserver"].port == 6443 && oci_network_load_balancer_backend.api_backends["kube_apiserver"].network_load_balancer_id == "ocid1.networkloadbalancer.oc1.iad.aaaaaaaaapi"
    error_message = "The backend is this instance, on the backend set's port, in the cluster's load balancer."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].create_vnic_details[0].subnet_id == "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane" && oci_core_instance.node_instance[0].create_vnic_details[0].nsg_ids == toset(["ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"])
    error_message = "A control-plane machine joins the control-plane subnet and NSG."
  }
  assert {
    condition     = output.failure_domain == "US-ASHBURN-AD-1"
    error_message = "demo-control-plane-abcde hashes to US-ASHBURN-AD-1."
  }
}

run "control_plane_rke2_registers_both_backends" {
  variables {
    control_plane = true
    captf_cluster_outputs = {
      schema                  = "captf.io/oci-cluster/v1"
      region                  = "us-ashburn-1"
      compartment_id          = "ocid1.compartment.oc1..aaaaaaaacluster"
      vcn_id                  = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
      control_plane_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane"
      worker_subnet_id        = "ocid1.subnet.oc1.iad.aaaaaaaaworkers"
      control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"
      worker_nsg_id           = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"
      failure_domains         = { "US-ASHBURN-AD-1" = { availability_domain = "Uocm:US-ASHBURN-AD-1" } }
      node_defined_tags       = {}
      api = {
        host                     = "10.0.0.10"
        port                     = 6443
        network_load_balancer_id = "ocid1.networkloadbalancer.oc1.iad.aaaaaaaaapi"
        kube_apiserver           = { backend_set_name = "kube-apiserver", port = 6443 }
        rke2_supervisor          = { backend_set_name = "rke2-supervisor", port = 9345 }
      }
    }
  }

  assert {
    condition     = oci_network_load_balancer_backend.api_backends["kube_apiserver"].port == 6443 && oci_network_load_balancer_backend.api_backends["rke2_supervisor"].port == 9345
    error_message = "An RKE2 control-plane machine registers on 6443 and 9345."
  }
}

run "control_plane_with_user_endpoint" {
  variables {
    control_plane = true
    captf_cluster_outputs = {
      schema                  = "captf.io/oci-cluster/v1"
      region                  = "us-ashburn-1"
      compartment_id          = "ocid1.compartment.oc1..aaaaaaaacluster"
      vcn_id                  = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
      control_plane_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane"
      worker_subnet_id        = "ocid1.subnet.oc1.iad.aaaaaaaaworkers"
      control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"
      worker_nsg_id           = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"
      failure_domains         = { "US-ASHBURN-AD-1" = { availability_domain = "Uocm:US-ASHBURN-AD-1" } }
      node_defined_tags       = {}
      api                     = null
    }
  }

  assert {
    condition     = length(oci_network_load_balancer_backend.api_backends) == 0
    error_message = "With a user-supplied endpoint (exports.api null) there is nothing to register in."
  }
}

run "failure_domain_requested" {
  variables {
    failure_domain = "US-ASHBURN-AD-2"
  }

  assert {
    condition     = output.failure_domain == "US-ASHBURN-AD-2" && oci_core_instance.node_instance[0].availability_domain == "Uocm:US-ASHBURN-AD-2"
    error_message = "A requested failure domain is honoured and reported unchanged."
  }
}

run "failure_domain_defaulted" {
  variables {
    failure_domain = null
    machine_name   = "demo-md-0-xyz12"
  }

  assert {
    condition     = output.failure_domain == "US-ASHBURN-AD-3" && oci_core_instance.node_instance[0].availability_domain == "Uocm:US-ASHBURN-AD-3"
    error_message = "Without a request the module picks deterministically from machine_name and reports it."
  }
}

run "failure_domain_fault_domain_mode" {
  variables {
    failure_domain = "FAULT-DOMAIN-2"
    captf_cluster_outputs = {
      schema                  = "captf.io/oci-cluster/v1"
      region                  = "us-sanjose-1"
      compartment_id          = "ocid1.compartment.oc1..aaaaaaaacluster"
      vcn_id                  = "ocid1.vcn.oc1.sjc.aaaaaaaavcn"
      control_plane_subnet_id = "ocid1.subnet.oc1.sjc.aaaaaaaacontrolplane"
      worker_subnet_id        = "ocid1.subnet.oc1.sjc.aaaaaaaaworkers"
      control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.sjc.aaaaaaaacontrolplane"
      worker_nsg_id           = "ocid1.networksecuritygroup.oc1.sjc.aaaaaaaaworkers"
      failure_domains = {
        "FAULT-DOMAIN-1" = { availability_domain = "Uocm:US-SANJOSE-1-AD-1", fault_domain = "FAULT-DOMAIN-1" }
        "FAULT-DOMAIN-2" = { availability_domain = "Uocm:US-SANJOSE-1-AD-1", fault_domain = "FAULT-DOMAIN-2" }
        "FAULT-DOMAIN-3" = { availability_domain = "Uocm:US-SANJOSE-1-AD-1", fault_domain = "FAULT-DOMAIN-3" }
      }
      node_defined_tags = {}
      api               = null
    }
  }

  assert {
    condition     = oci_core_instance.node_instance[0].availability_domain == "Uocm:US-SANJOSE-1-AD-1" && oci_core_instance.node_instance[0].fault_domain == "FAULT-DOMAIN-2"
    error_message = "A fault-domain failure domain pins both the availability domain and the fault domain."
  }
}

run "spot_is_interruptible" {
  variables {
    preemptible = true
  }

  assert {
    condition     = output.interruptible == true
    error_message = "A preemptible instance is interruptible."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].preemptible_instance_config[0].preemption_action[0].type == "TERMINATE" && oci_core_instance.node_instance[0].preemptible_instance_config[0].preemption_action[0].preserve_boot_volume == false
    error_message = "A preempted instance is terminated with its boot volume."
  }
}

run "node_defined_tags_applied" {
  variables {
    captf_cluster_outputs = {
      schema                     = "captf.io/oci-cluster/v1"
      region                     = "us-ashburn-1"
      compartment_id             = "ocid1.compartment.oc1..aaaaaaaacluster"
      vcn_id                     = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
      control_plane_subnet_id    = "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane"
      worker_subnet_id           = "ocid1.subnet.oc1.iad.aaaaaaaaworkers"
      control_plane_nsg_id       = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"
      worker_nsg_id              = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"
      failure_domains            = { "US-ASHBURN-AD-1" = { availability_domain = "Uocm:US-ASHBURN-AD-1" } }
      node_defined_tags          = { "captf.cluster" = "team-a/demo" }
      control_plane_defined_tags = { "captf.cluster" = "team-a/demo/control-plane" }
      api                        = null
    }
  }

  assert {
    condition     = oci_core_instance.node_instance[0].defined_tags == tomap({ "captf.cluster" = "team-a/demo" })
    error_message = "The instance must carry the defined tag the cluster's dynamic group matches."
  }
}

run "control_plane_defined_tag_applied" {
  variables {
    control_plane = true
    captf_cluster_outputs = {
      schema                     = "captf.io/oci-cluster/v1"
      region                     = "us-ashburn-1"
      compartment_id             = "ocid1.compartment.oc1..aaaaaaaacluster"
      vcn_id                     = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
      control_plane_subnet_id    = "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane"
      worker_subnet_id           = "ocid1.subnet.oc1.iad.aaaaaaaaworkers"
      control_plane_nsg_id       = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"
      worker_nsg_id              = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"
      failure_domains            = { "US-ASHBURN-AD-1" = { availability_domain = "Uocm:US-ASHBURN-AD-1" } }
      node_defined_tags          = { "captf.cluster" = "team-a/demo" }
      control_plane_defined_tags = { "captf.cluster" = "team-a/demo/control-plane" }
      api                        = null
    }
  }

  assert {
    condition     = oci_core_instance.node_instance[0].defined_tags == tomap({ "captf.cluster" = "team-a/demo/control-plane" })
    error_message = "A control-plane machine must carry the control-plane tag value, the only one the cluster's dynamic group matches."
  }
}

run "public_ip_and_ssh" {
  variables {
    public_ip           = true
    ssh_authorized_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample operator@example.com"]
  }

  override_resource {
    target = oci_core_instance.node_instance
    values = {
      private_ip = "10.0.0.23"
      public_ip  = "198.51.100.23"
      state      = "RUNNING"
    }
  }
  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  assert {
    condition     = output.addresses == [{ type = "InternalIP", address = "10.0.0.23" }, { type = "ExternalIP", address = "198.51.100.23" }]
    error_message = "A public instance reports its public IP as ExternalIP, as the cloud controller manager does."
  }
  assert {
    condition     = oci_core_instance.node_instance[0].create_vnic_details[0].assign_public_ip == "true"
    error_message = "public_ip must reach the VNIC."
  }
  assert {
    condition     = nonsensitive(oci_core_instance.node_instance[0].metadata["ssh_authorized_keys"]) == "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample operator@example.com"
    error_message = "SSH keys go into the instance metadata."
  }
}

run "fixed_shape_has_no_shape_config" {
  variables {
    shape = "VM.Standard2.4"
  }

  plan_options {
    replace = [oci_core_instance.node_instance[0]]
  }

  assert {
    condition     = length(oci_core_instance.node_instance[0].shape_config) == 0
    error_message = "A fixed shape takes no OCPU or memory settings."
  }
}

run "externally_managed_with_override" {
  variables {
    captf_cluster_outputs = {}
    external_cluster_exports = {
      schema                  = "captf.io/oci-cluster/v1"
      region                  = "us-phoenix-1"
      compartment_id          = "ocid1.compartment.oc1..aaaaaaaaexternal"
      vcn_id                  = "ocid1.vcn.oc1.phx.aaaaaaaavcn"
      control_plane_subnet_id = "ocid1.subnet.oc1.phx.aaaaaaaacontrolplane"
      worker_subnet_id        = "ocid1.subnet.oc1.phx.aaaaaaaaworkers"
      control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.phx.aaaaaaaacontrolplane"
      worker_nsg_id           = "ocid1.networksecuritygroup.oc1.phx.aaaaaaaaworkers"
      failure_domains         = { "PHX-AD-1" = { availability_domain = "Uocm:PHX-AD-1" } }
      node_defined_tags       = {}
      api                     = null
    }
  }

  assert {
    condition     = oci_core_instance.node_instance[0].compartment_id == "ocid1.compartment.oc1..aaaaaaaaexternal" && oci_core_instance.node_instance[0].availability_domain == "Uocm:PHX-AD-1"
    error_message = "An externally managed cluster's machines use external_cluster_exports."
  }
  assert {
    condition     = local.region == "us-phoenix-1"
    error_message = "The provider region comes from external_cluster_exports."
  }
}

run "externally_managed_without_override" {
  command = plan

  variables {
    captf_cluster_outputs = {}
  }

  expect_failures = [oci_core_instance.node_instance]
}

run "wrong_exports_schema" {
  command = plan

  variables {
    captf_cluster_outputs = {
      schema = "captf.io/aws-cluster/v1"
      region = "us-east-1"
    }
  }

  expect_failures = [var.captf_cluster_outputs]
}

run "unknown_failure_domain" {
  command = plan

  variables {
    failure_domain = "US-ASHBURN-AD-9"
  }

  expect_failures = [oci_core_instance.node_instance]
}

run "bootstrap_cloud_config" {
  assert {
    condition     = nonsensitive(oci_core_instance.node_instance[0].metadata["user_data"]) == "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvXQo="
    error_message = "cloud-config bootstrap data goes to user_data unchanged (OCI takes base64)."
  }
}

run "bootstrap_ignition" {
  variables {
    # base64 of {"ignition":{"version":"3.4.0"}}
    bootstrap_data   = "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
    bootstrap_format = "ignition"
  }

  assert {
    condition     = nonsensitive(oci_core_instance.node_instance[0].metadata["user_data"]) == "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
    error_message = "Ignition bootstrap data goes to user_data unchanged."
  }
}

run "bootstrap_gzip" {
  variables {
    # base64 of a gzipped cloud-config (CAPRKE2 gzipUserData)
    bootstrap_data = "H4sIAAAAAAAC/1NOzskvTdFNzs9Ly0znKirNS85NsVKITk3OyFfISM3JyY/lAgDckH8lIwAAAA=="
  }

  assert {
    condition     = nonsensitive(oci_core_instance.node_instance[0].metadata["user_data"]) == "H4sIAAAAAAAC/1NOzskvTdFNzs9Ly0znKirNS85NsVKITk3OyFfISM3JyY/lAgDckH8lIwAAAA=="
    error_message = "A gzipped payload goes to user_data unchanged; cloud-init decompresses it."
  }
}

run "bootstrap_too_large" {
  command = plan

  variables {
    # 36,000 base64 characters: over OCI's 32,000-byte metadata limit.
    bootstrap_data = join("", [for i in range(1000) : "SGVsbG8sIHdvcmxkISBIZWxsbywgd29ybGQh"])
  }

  expect_failures = [oci_core_instance.node_instance]
}

run "rejects_spot_control_plane" {
  command = plan

  variables {
    control_plane = true
    preemptible   = true
  }

  expect_failures = [oci_core_instance.node_instance]
}

run "rejects_too_many_tags" {
  command = plan

  variables {
    captf_tags = {
      "captf.io/cluster"    = "demo"
      "captf.io/namespace"  = "team-a"
      "captf.io/kind"       = "TerraformMachine"
      "captf.io/name"       = "demo-md-0-abcde"
      "captf.io/managed-by" = "captf"
      "captf.io/template"   = "demo-md-0"
      "captf.io/future"     = "x"
    }
    additional_tags = { a = "1", b = "2", c = "3", d = "4" }
  }

  expect_failures = [oci_core_instance.node_instance]
}

run "rejects_gzipped_ignition" {
  command = plan

  variables {
    bootstrap_format = "ignition"
    # base64 of a gzipped payload
    bootstrap_data = "H4sIAAAAAAAC/1NOzskvTdFNzs9Ly0znKirNS85NsVKITk3OyFfISM3JyY/lAgDckH8lIwAAAA=="
  }

  expect_failures = [oci_core_instance.node_instance]
}
