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

# A control-plane machine registers itself in every backend set of the API
# network load balancer, in its own state, so destroying the machine
# deregisters it (machine.md "Control-plane machines"). The instance exists
# and runs before this is created, seconds into a boot whose kubeadm init or
# join takes minutes. Workers and user-supplied endpoints register nowhere.
resource "oci_network_load_balancer_backend" "api_backends" {
  for_each = local.api_backend_sets

  backend_set_name         = each.value.backend_set_name
  network_load_balancer_id = local.api_load_balancer_id
  port                     = each.value.port
  target_id                = oci_core_instance.node_instance[0].id
}
