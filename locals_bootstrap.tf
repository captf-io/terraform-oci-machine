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

# Instance metadata. OCI takes user_data base64-encoded, which bootstrap_data
# already is, so it passes through unchanged for every format: cloud-config,
# Ignition and a gzipped payload alike (CONVENTIONS.md section 13).
# metadata and extended_metadata together may hold 32,000 bytes:
# https://docs.oracle.com/en-us/iaas/api/#/en/iaas/latest/LaunchInstanceDetails
locals {
  metadata = merge(
    { user_data = var.bootstrap_data },
    length(var.ssh_authorized_keys) == 0 ? {} : { ssh_authorized_keys = join("\n", var.ssh_authorized_keys) },
  )
  metadata_limit_bytes = 32000
  # The size of what is sent is not secret, only the payload is.
  metadata_bytes = nonsensitive(length(jsonencode(local.metadata)))
}
