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

# OCI free-form tags for every taggable resource (CONVENTIONS.md section 7).
# Free-form tag keys may not contain periods or spaces, so captf.io/<key>
# becomes captf_io/<key>; a resource carries at most 10 free-form tags:
# https://docs.oracle.com/en-us/iaas/Content/Tagging/Concepts/taggingoverview.htm
# ("Limits on Tags").
locals {
  captf_tags = { for k, v in var.captf_tags : replace(replace(k, ".", "_"), " ", "_") => v }
  # The OCI cloud controller manager requires no tags.
  cloud_tags = {}
  # The captf keys merge last, so additional_tags cannot override them.
  tags = merge(var.additional_tags, local.cloud_tags, local.captf_tags)

  # Tenancy tag defaults stamp these on every resource; managing them would
  # show a diff on every plan.
  ignore_defined_tags = distinct(concat(["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"], var.ignore_defined_tags))
}
