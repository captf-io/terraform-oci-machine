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

# The cluster's exports (schema captf.io/oci-cluster/v1, README "Exports"):
# captf_cluster_outputs, or external_cluster_exports when the TerraformCluster
# is externally managed and the controller passes {} (CONVENTIONS.md
# section 12). Every read is try()-guarded so a missing value reaches the
# precondition on node_instance.tf instead of failing an expression first.
locals {
  externally_managed = try(length(var.captf_cluster_outputs), 0) == 0
  # Tuple index, not a conditional: a conditional would try to unify {} with
  # the exports object and fail on its mixed attribute types.
  exports = [var.captf_cluster_outputs, var.external_cluster_exports][local.externally_managed ? 1 : 0]

  region         = try(local.exports.region, null)
  compartment_id = try(local.exports.compartment_id, null)
  node_subnet_id = try(var.control_plane ? local.exports.control_plane_subnet_id : local.exports.worker_subnet_id, null)
  node_nsg_id    = try(var.control_plane ? local.exports.control_plane_nsg_id : local.exports.worker_nsg_id, null)
  # Control-plane machines carry the cluster's control-plane tag value, which
  # alone the cluster's node dynamic group matches.
  node_defined_tags       = try(var.control_plane ? local.exports.control_plane_defined_tags : local.exports.node_defined_tags, {})
  cluster_failure_domains = try(local.exports.failure_domains, {})

  # Control-plane machines register in the backend set of every API listener
  # (machine.md "Control-plane machines"), each { backend_set_name, port };
  # none with a user-supplied endpoint (api null).
  api_backend_sets = !var.control_plane ? {} : {
    for listener in ["kube_apiserver", "rke2_supervisor"] : listener => local.exports.api[listener]
    if try(local.exports.api[listener].backend_set_name, null) != null
  }
  api_load_balancer_id = try(local.exports.api.network_load_balancer_id, null)
}
