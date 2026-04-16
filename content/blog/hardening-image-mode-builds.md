---
title: "Experiences using and hardening RHEL image mode"
description: "How to enforce supply chain integrity on RHEL image mode (bootc) appliances using cosign signature verification, SELinux lockdown, and filesystem immutability, and where the ecosystem is headed with composefs and IMA."
author: "Chris Butler"
date: 2026-03-25
draft: false
categories:
  - Red Hat Enterprise Linux
  - Security
  - bootc
  - Supply Chain

---

# Hardening RHEL Image mode for mission critical environments.

To me the idea of image mode, or upstream bootc, is inherently appealing. My memory for fine details is a sieve, and I don't trust myself not to skip documenting a step. Forcing the workthrough through the source code management system may slow me down in the short term, however, provides long term benefits. The challenge is in building enough of a skeleton that projects 2, 3 and 4 are faster. The great thing about AI is with a valid skeleton the projects are greatly accelerated.

When using image mode myself, and discussing with other users a few topics came up repeatedly:

1. How do you manage and ensure the correctness of builds?
2. What tools do you use to enforce security? I want to control what images are allowed to be used.
3. How do you manage layering and lifecycling in an enterprise context (e.g fleets and derived images)?

These questions become critical as the first use cases that people think about for image mode is critical security appliances and edge devices where image mode's atomic updates provide significant value..

This blog will walk through 1 and 2 based on my experiences in building a developer's bastion host, which is in my [rhel-dev](https://github.com/tempest-concorde/rhel-dev/) project.

<!-- more -->

## Managing build correctness

Bootc (image mode), does make it easy to manage OS images. The challenge, like with any container image is to put a sensible CICD process around it to ensure there is no pushing from developer workstations. For personal or upstream projects GitHub actions is an obvious choice for CICD. Unfortunately today there are no RHEL native builders on GitHub, so I built on the [community workflow](https://github.com/redhat-cop/redhat-image-mode-actions). At a high level:

- Stand up a UBI container
- Authenticate with Red Hat to be able to pull RPMs / image mode OCI Images.
- Build your image (leveraging the authentication credentials)
- Push the image and clean up credentials.

Initially the workflow seems a bit awkward, however, the reason why is pretty clear: your end OS images cannot authenticate with Red Hat and are not intended to - your build system gates where you authenticate with Red Hat. This has a nice side benefit in an enterprise as it makes it really clear where RHEL images are being built as the developer should never need credentials to authenticate with Red Hat.

I wrapped this in my standard set of tooling:

- **Conventional commits and PR validation.** Commitlint enforces commit message conventions, and every PR triggers a full build to catch regressions before merge
- Automated releases based on semantic-release from the commit messages.

There are a few 'gotchas' to be aware of when building bootc images. The most important one is you absolutely must run `bootc container lint` as the last step in your `Containerfile`. There are destructive actions that you can perform, such as incorrectly configuring kernel arguments, which can put a bootc image in an unbootable state. `bootc container lint` significantly decreases the risk.

There were a few additional steps I added to the build process:

**Validation of the registry.** After every release build, the CI pipeline verifies that the pushed image is correctly signed using `cosign verify`. This catches signing failures before they reach deployed systems. The workflow also uses `skopeo inspect` to confirm the manifest and tags are present in the registry. This simple smoke test has caught auth and push failures more than once.

**Multi-architecture builds.** I develop on both arm and x86 platforms, so the pipeline builds both architectures and merges them into a single manifest. The single manifest prevents fat fingering issues resulting in failed deployments and `bootc update` pulls the right architecture automatically (I learned the hard way that bootc will pull the wrong architecture if you do something silly). The images are built in a matrix, and a [final job creates the merged manifest and signs all tags](https://github.com/tempest-concorde/rhel-dev/blob/cf803ff580d5b39d6d2037ed3b059be71502394f/.github/workflows/build-release.yml#L120-L229).

**Build hardening and attestation.** This is a work in progress. The CI workflow already applies [CIS RHEL 10 hardening](https://www.open-scap.org/) via OpenSCAP remediation at build time. The SCAP tools are installed, remediation runs against the CIS profile, and the tools are removed in the same layer so the runtime image stays lean. SLSA verification and build hardening is a WIP.

The result is that the `main` branch always represents a buildable, lintable, CIS-hardened image. Tagged releases are automatically built, signed, and pushed to the registry.

## Controlling which images can run

With the build pipeline producing trustworthy images, the next question is: how do you ensure only *those* images run on deployed systems?

When your operating system updates via `bootc update`, it pulls a new image from a registry and stages it as an [ostree](https://ostreedev.github.io/ostree/) deployment. Container registries are mutable: tags can be overwritten. You need cryptographic proof that the image was built by your CI pipeline. [Cosign](https://github.com/sigstore/cosign) provides this by signing image digests and storing signatures alongside the image in the registry.

### Signing in CI

Cosign supports two signing modes: keyless (OIDC-based, where Sigstore's Fulcio CA issues a short-lived certificate tied to your identity) and key-based (a traditional keypair you manage). Keyless signing is appealing because there's no private key to protect, but the `containers/image` policy engine validates keyless signatures by matching on an email-based identity (`signedIdentity`). GitHub Actions OIDC tokens don't carry an email claim, so there's no identity to match against. Until `containers/image` supports matching on GitHub Actions workflow identities directly, key-based signing is the practical choice for CI pipelines.

In a GitHub Actions workflow, you store the cosign private key as a repository secret and sign after pushing:

```bash
cosign sign --key env://COSIGN_PRIVATE_KEY \
  --yes \
  -a tag=${TAG} \
  -a sha=${GITHUB_SHA} \
  ${IMAGE}@${DIGEST}
```

One important detail: cosign v3 defaults to the [OCI 1.1 Referrers API](https://opencontainers.org/posts/blog/2024-03-13-image-and-distribution-1-1/) for storing signatures. The `containers/image` library (which powers podman, skopeo, and bootc) doesn't support OCI 1.1 referrers for signature discovery yet. It only reads legacy tag-based `.sig` attachments. This isn't a blocker; you just need to pin cosign to v2.x in your CI workflow via the `cosign-release` input on [sigstore/cosign-installer](https://github.com/sigstore/cosign-installer). Cosign v2 creates tag-based attachments by default, and everything works.

### Ensuring a bootc system is on a known and secure image train

With signing in place, the next step is configuring the deployed system so it will only accept images from your signed repository. Two configuration files lock the system to your image train.

`/etc/containers/policy.json` defines a reject-all default with an exception for your signed repository:

```json
{
  "default": [{ "type": "reject" }],
  "transports": {
    "docker": {
      "quay.io/your-org/your-image": [{
        "type": "sigstoreSigned",
        "keyPath": "/usr/share/pki/sigstore/cosign.pub",
        "signedIdentity": { "type": "matchRepository" }
      }]
    }
  }
}
```

A registries.d configuration tells `containers/image` where to find the signatures:

```yaml
docker:
  quay.io/your-org/your-image:
    use-sigstore-attachments: true
```

This file **must** live in `/etc/containers/registries.d/`. I learned the hard way that `/usr/share/containers/registries.d/` (where some distro packages place their defaults) is not a valid lookup path for `containers/image`. If the file is in the wrong directory, signature discovery silently fails with "A signature was required, but no signature exists." when you run `bootc upgrade`.

With both files in place, `bootc update` and `podman pull` will refuse any image that isn't signed by your key. The public key lives at `/usr/share/pki/sigstore/cosign.pub`, inside the read-only `/usr` filesystem and can't be tampered with at runtime.

Bootc also supports enforcing kernel arguments via `/usr/lib/bootc/kargs.d/`. In the image we set `selinux=1` and `enforcing=1`, which are written into the bootloader (GRUB) configuration at deployment time. This ensures SELinux is always active and enforcing from the earliest point in boot. A user can't simply add `selinux=0` to the kernel command line to bypass it.

This is the complete image train: CI signs the image, the registry stores the signature, the deployed system verifies it against a trust anchor in read-only storage, and kernel arguments enforce SELinux from boot. For appliances or headless systems with no interactive root user, this is solid. The system will only ever run images signed by your key, SELinux is always enforcing, and `bootc update` handles the rest automatically.

### Pulling from a private registry

A signed image in a private registry is only useful if the deployed system can authenticate to pull it. On a bootc system, `bootc update` uses `/etc/ostree/auth.json` for registry credentials. This file follows the same format as Docker/Podman auth configs (a JSON object with base64-encoded credentials per registry).

The cleanest way to provision this is through the kickstart in the [blueprint file](https://osbuild.org/docs/user-guide/blueprint-reference). In the rhel-dev project, the install image is built with [bootc-image-builder](https://github.com/osbuild/bootc-image-builder). It's important to know that you don't have the full spectrum of facilities your have when using an rpm build with kickstart, bootc-image-builder automatically injects in the configuration to use the container image.
When you do this the `post` command is after the container image is mounted. Allowing us to persist data on top of the container image:

`%post`:

```bash
%post
mkdir -p /etc/ostree
cat > /etc/ostree/auth.json << 'EOF'
{ "auths": { "quay.io": { "auth": "<base64>" } } }
EOF
%end
```

The template reads the credentials from a local Docker auth file at build time, so they never appear in source control. This approach keeps credentials out of the container image itself (where they would be visible to anyone who can pull the image) and provisions them only on the target system during installation.

## Defence in depth: protecting against root

The update chain above is trustworthy, but what about a user with `sudo`? A root user could edit `policy.json` to change the default from `reject` to `insecureAcceptAnything`, bypassing the entire verification chain. On a single-user developer bastion host, this is a realistic concern.

On a bootc system, `/usr` is read-only via [composefs](https://github.com/composefs/composefs), so the public key and binaries are protected by the filesystem itself. But `/etc` is writable (it has to be for system configuration) and the policy files live there. We need additional layers.

The approach I've settled on combines filesystem attributes and SELinux hardening via a systemd oneshot service that runs after the system is fully booted:

```ini
[Unit]
Description=Lock SELinux policy state and protect critical files
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/chattr +i /etc/containers/policy.json /etc/containers/registries.d/quay.io-rhel-dev.yaml
ExecStart=/usr/sbin/setsebool -P secure_mode_policyload=1 secure_mode_insmod=1 secure_mode=1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

This does two things. `chattr +i` sets the immutable flag on the policy files. Even root cannot modify or delete an immutable file without first clearing the flag. The SELinux booleans then lock down the enforcement mechanism itself: `secure_mode` prevents `setenforce 0`, `secure_mode_policyload` prevents loading new SELinux policy modules, and `secure_mode_insmod` prevents loading kernel modules. These booleans are set atomically in a single call. This is important because setting `secure_mode_policyload` first would block the remaining boolean changes.

Combined with kernel arguments (`selinux=1 enforcing=1` via bootc's `kargs.d`) and `chmod 0444` baked into the image, this creates a layered defence. A root user who wants to tamper with the policy would need to reboot the system and act during the window between boot and the lockdown service. That's a real constraint, but it's not an impenetrable one.

### The gap: boot chain integrity

The limitation today is that we aren't enforcing integrity through the entire boot chain. [composefs](https://ostreedev.github.io/ostree/composefs/) already protects `/usr` as a read-only filesystem with content validation, but there is no mechanism yet to verify files in `/etc` before they are used. A complete solution would use [IMA](https://ostreedev.github.io/ostree/ima/) (Integrity Measurement Architecture) to validate every file against a signed manifest at the kernel level, closing the boot window entirely alongside enforcing it runs with UKI.

There is [active upstream discussion](https://github.com/bootc-dev/bootc/discussions/1129) about bringing IMA support into bootc, and [ostree is evolving its IMA integration](https://github.com/ostreedev/ostree/issues/2609) in parallel.

## Where we are now

The update chain today is secure when automated: cosign signing in CI, signature verification on the appliance, and a trust anchor in read-only storage. For systems without interactive root access, this is sufficient. For systems with root users, the defence-in-depth layers (immutable flags, SELinux lockdown, read-only `/usr`) raise the bar significantly while we wait for IMA to close the remaining gap. Realistically this is better than most enterprise deployments today where root users can easily and freely install packages. Triggering a reboot, breaking file immutability provides clear signals to a SOC that something bad is happening.

If you want to see a working example, the [rhel-dev](https://github.com/tempest-concorde/rhel-dev) project implements everything described here: cosign signing in GitHub Actions, policy.json enforcement, SELinux lockdown, and CIS hardening on a RHEL 10 bootc image.
