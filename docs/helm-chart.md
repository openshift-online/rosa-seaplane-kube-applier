# kube-applier Helm OCI chart

The chart source of truth is [`charts/kube-applier`](../charts/kube-applier). It was initially
copied from the Management Cluster chart in public
[`rosa-seaplane`](https://github.com/openshift-online/rosa-seaplane/tree/main/argocd/config/management-cluster/kube-applier);
that original source remains in `Chart.yaml` metadata. The `kube-applier` chart is configured to be
published as a Helm OCI artifact by the chart-specific Konflux PipelineRuns in `.tekton/`.

## Artifact and versioning

The PipelineRuns clone the repository's full history and Git tags through the digest-pinned
trusted-artifact task, then invoke Konflux's digest-pinned `build-helm-chart-oci-ta` task. Full
history and tags are required for the task's Git-based version calculation. That task runs Helm
chart packaging and OCI push; it does not wrap the `.tgz` in an ordinary container image. The
source chart's `version: 0.1.0` is valid local package metadata; main builds calculate and pass a
version from Git instead. On `main`, the task resolves a SemVer chart version from two-component
`helm-X.Y` Git tags and commit distance, falling back to
`0.1.<commit-count>+<short-sha>` if no matching tag is present. Use the `helm-X.Y` form (not
`helm-X.Y.Z`) because the official resolver converts the commit distance after the tag into the
patch component. Main-build `appVersion` defaults to the full source commit SHA, matching the
controller image pipeline's `:<revision>` tag. Pull requests use a unique
`0.1.0-pr.<full-sha>` prerelease version and set `appVersion` to the matching controller image
`on-pr-<sha>` tag; they do not reuse the main-build chart version.

The repository currently has no `helm-*` tags; its existing `v*` tags do not match the configured
prefix, so main builds use the fallback until an immutable numeric `helm-X.Y` tag is introduced.

The PipelineRun is configured to publish the OCI chart at this planned destination (the repository
and its availability are not provisioned or verified by this change):

```text
quay.io/redhat-user-workloads/rosa-tenant/kube-applier:<chart-version>
```

Helm OCI tags replace SemVer build-metadata `+` with `_` in the registry, as Helm specifies. Use
the original SemVer value in Helm dependency metadata. The task also copies the chart to a
chart-specific tag in the component image repository (`chart-on-pr-<sha>` for pull requests,
`chart-<sha>` on `main`) for Konflux build traceability. These tags intentionally differ from the
controller image's `on-pr-<sha>` and `<revision>` tags so the chart copy cannot overwrite the
controller image. Configure registry retention for the chart-specific PR tags and decide whether to
expire the chart repository's `-pr.*` tags; the task does not provide registry-side tag expiry for
its SemVer chart path.

## Consumer reference

The public `rosa-seaplane` repo uses Helm dependencies in `Chart.yaml`, OCI repositories, and
committed `Chart.lock`/`.tgz` dependency archives (for example,
[`argocd/config/shared/karpenter/Chart.yaml`](https://github.com/openshift-online/rosa-seaplane/blob/main/argocd/config/shared/karpenter/Chart.yaml)
and [`argocd/config/regional-cluster/thanos-operator/Chart.yaml`](https://github.com/openshift-online/rosa-seaplane/blob/main/argocd/config/regional-cluster/thanos-operator/Chart.yaml)). A consumer wrapper chart can declare:

```yaml
dependencies:
  - name: kube-applier
    version: "0.1.42+abcdef0"
    repository: "oci://quay.io/redhat-user-workloads/rosa-tenant"
```

`0.1.42+abcdef0` is an illustrative version exercised in the disposable local-registry round trip;
it is not a Quay publication or a Konflux build result. After a successful `main` PipelineRun and
registry onboarding, take the version from the tag in its `IMAGE_URL` result. The OCI tag encodes
`+` as `_`; convert that underscore back to `+` in the dependency's `version`, as shown.
Then run `helm dependency update <wrapper-chart-directory>` and commit both `Chart.lock` and the
downloaded `charts/kube-applier-<version>.tgz`, following the consumer repository's dependency-lock
checks. Helm's OCI dependency rule is that `repository` omits the chart basename; Helm appends the
dependency name and version. The chart can also be pulled directly with
`helm pull oci://quay.io/redhat-user-workloads/rosa-tenant/kube-applier --version 0.1.42+abcdef0`.

## Konflux and registry onboarding

This change adds repository-side PipelineRuns only; it does not create or modify Konflux or Quay
resources. Before enabling the pipeline, the owning team must verify or configure:

- The existing `rosa-tenant` Konflux namespace, Application/Component, Pipelines-as-Code GitHub
  integration, and `build-pipeline-rosa-seaplane-kube-applier` service account are active for this
  repository.
- The existing component image repository remains
  `quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-kube-applier`; its credentials must
  permit the task's traceability copy to the `chart-on-pr-<sha>` and `chart-<sha>` tags. These are
  separate from the controller image tags published by the existing image PipelineRuns.
- A Quay OCI repository at
  `quay.io/redhat-user-workloads/rosa-tenant/kube-applier` exists (or can be created by the task's
  credentials), is writable by the task, and is public/readable to `rosa-seaplane` consumers.
  The task derives that chart path from the component image repository's tenant-level parent and
  the `kube-applier` chart name. Do not assume the repository or required write permission already
  exists.
- Registry retention is agreed for temporary pull-request artifacts. Both the component's
  `chart-on-pr-*` traceability tags and chart repository's `0.1.0-pr.*` SemVer tags are distinct
  from main tags but remain in the registry until its cleanup policy removes them.

No consumer change is included here. Once the artifact repository is provisioned and public, a
consumer chart can add the dependency above and vendor its lock/archive through its existing
`helm dependency update` workflow.

## Local validation

Run the chart's local checks with a Helm CLI installed:

```bash
make helm-test
```

The build pipeline's `build-helm-chart-oci-ta` task performs the package and registry push. Helm
defines the OCI chart config and content layer media types as
`application/vnd.cncf.helm.config.v1+json` and
`application/vnd.cncf.helm.chart.content.v1.tar+gzip`; see the
[Helm OCI registry documentation](https://helm.sh/docs/topics/registries/).
