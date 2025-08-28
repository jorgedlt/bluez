Got it — your current README is still describing the **old single-file `bluezfuncs.sh` world**, but now you’ve modularized the repo with `loader.sh`, `init.sh`, and `functions/*.sh`, plus a `tests/` directory. Let me rewrite the README so it reflects the **new structure and workflow**.

Here’s a full updated `README.md`:

```markdown
# Bluez IBM Cloud Functions

## Overview

This repository provides a modular set of Bash helper functions for the IBM Cloud CLI.  
The helpers simplify common DevOps workflows: targeting accounts, managing resource groups, listing VPC instances, Kubernetes clusters, IAM groups, Key Protect keys, and Cloud Object Storage.  
Functions are split into logical modules under `functions/` and are loaded automatically by `loader.sh`.

## Layout

```

.
├── loader.sh            # Main entrypoint, sources init + all function modules
├── init.sh              # Shared configuration, env setup, bootstrap
├── functions/           # Individual categories of functions
│   ├── login.sh
│   ├── iam.sh
│   ├── devops.sh
│   ├── resources.sh
│   ├── tags.sh
│   ├── vpc.sh
│   ├── k8s.sh
│   ├── keyprotect.sh
│   ├── cos.sh
│   ├── iam\_access.sh
│   └── misc.sh
└── tests/
├── smoke.sh         # Smoke test (RG create/list/show/delete)
└── smoke\_helpers.sh # Helpers for smoke test

````

## Installation

Clone this repo and source the loader:

```bash
git clone https://github.com/jorgedlt/bluez.git ~/git/bluez
cd ~/git/bluez
source ./loader.sh
````

Add to your shell profile (`~/.bashrc` or `~/.zshrc`) for persistence:

```bash
source ~/git/bluez/loader.sh
```

## Usage

Run functions directly after sourcing `loader.sh`.
Examples:

* `ibmlogin` — Authenticate into IBM Cloud CLI.
* `ibmwhoami` — Show current IBM Cloud target (account, region, resource group, user).
* `ibmrgls` — List resource groups.
* `ibmrgmk demo-rg` — Create a resource group.
* `ibmrgrm demo-rg --force` — Delete a resource group.
* `ibmvmls` — List VPC instances.
* `ibmksls` — List Kubernetes clusters.
* `ibmrosa` — List OpenShift clusters.
* `ibmcosbuckets` — List Cloud Object Storage buckets.

For quick region targeting:

* `qsu` — Target **us-south** + default RG.
* `qsee` — Target **eu-de** + default RG.

## Testing

Run the included smoke test:

```bash
./tests/smoke.sh
```

This will:

1. Log in
2. Create a temporary resource group
3. List and show it
4. Delete it
5. Verify cleanup

## Requirements

* IBM Cloud CLI (`ibmcloud`) installed and authenticated.
* `jq` installed for JSON parsing.
* IBM Cloud CLI plugins as needed:

  * `is` (VPC)
  * `ks` (Kubernetes)
  * `oc` (OpenShift)
  * `kp` (Key Protect)
  * `cos` (Cloud Object Storage)

## Notes

* All functions are prefixed with `ibm` for clarity.
* Modules are idempotent and safe to reload.
* Only exports truly global variables; most helpers use locals.
* See `tests/smoke.sh` for an example workflow.

---

### Description (for GitHub/GitLab)

A modular Bash utility collection providing quick helpers for IBM Cloud CLI.
Functions streamline tasks such as switching accounts, managing resource groups, listing VPC instances, working with Kubernetes and OpenShift clusters, handling IAM users and groups, managing Key Protect keys, and browsing Cloud Object Storage. Designed for DevOps engineers who want faster day-to-day interaction with IBM Cloud.

```

---

Do you want me to also add a short **“Quickstart Demo”** section in the README showing the exact 3-4 commands we’ve been using (`source loader.sh`, `ibmlogin`, `ibmrgls`, `ibmrgmk demo-rg`, etc.) so anyone can immediately see it in action?
```
