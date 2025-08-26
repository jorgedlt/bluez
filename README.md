# README for `bluezfuncs.sh`

## Overview

This script provides a set of Bash helper functions for IBM Cloud CLI, similar in spirit to Azure or AWS helper sets. The functions simplify targeting accounts, regions, and resource groups, as well as listing and managing resources such as VPC instances, resource groups, Kubernetes clusters, IAM groups, Key Protect keys, and Cloud Object Storage. It also includes helpers for tagging, floating IPs, and security groups.

## Installation

1. Save the script as `~/.ibmfuncs.sh`.
2. Add the following to your `~/.bashrc` or `~/.zshrc`:

   ```bash
   source ~/.ibmfuncs.sh
   ```
3. Reload your shell.

## Usage

* Run `ibmhelp` to see a list of available functions, or `ibmhelp <keyword>` to search by topic.
* Common commands:

  * `ibmwhoami` — Show current IBM Cloud target (account, region, resource group, user).
  * `ibmaccls` — List available accounts.
  * `ibmpick` — Interactive account switcher.
  * `ibmtarget <region> [resource_group]` — Set target region and resource group.
  * `ibmrgls` — List resource groups.
  * `ibmresls` — List all service instances.
  * `ibmvmls` — List VPC instances.
  * `ibmksls` — List Kubernetes clusters.
  * `ibmrosa` — List Red Hat OpenShift clusters.
  * `ibmusers` — List account users.
  * `ibmcosbuckets` — List Cloud Object Storage buckets.

## Requirements

* IBM Cloud CLI (`ibmcloud`) installed and authenticated.
* `jq` installed for JSON parsing.
* Access rights to relevant accounts, regions, and resources.

## Notes

* Shortcuts like `qsu` and `qsee` quickly target common regions.
* Use `ibmclr` to clear IBM Cloud-related environment variables.
* Some functions rely on specific plugins (`is`, `ks`, `oc`, `kp`, `cos`) being installed in the IBM Cloud CLI.

---

### GitLab Description

A Bash utility collection providing quick helpers for IBM Cloud CLI. These functions streamline routine IBM Cloud tasks such as switching accounts, managing resource groups, listing VPC instances, working with Kubernetes and OpenShift clusters, handling IAM users and groups, managing Key Protect keys, and browsing Cloud Object Storage. Designed for DevOps engineers who need faster day-to-day interaction with IBM Cloud services.
