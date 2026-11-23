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

The PipelineRuns keep `Chart.yaml` `name: kube-applier` (`OVERWRITE_CHART_NAME: false`) and publish
the OCI chart into the existing component ImageRepository
(`PUSH_CHART_TO_IMAGE_REPOSITORY: true`):

```text
quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-kube-applier:<chart-version>
```

That is the repository the `build-pipeline-rosa-seaplane-kube-applier` credentials can write. The
default task path (`oci://<tenant>/<chart-name>`) would target
`quay.io/redhat-user-workloads/rosa-tenant/kube-applier`, which this robot cannot create.

Helm OCI tags replace SemVer build-metadata `+` with `_` in the registry, as Helm specifies. Use
the original SemVer value in Helm commands. The task also copies the chart to a chart-specific tag
in the same repository (`chart-on-pr-<sha>` for pull requests, `chart-<sha>` on `main`) for Konflux
build traceability. These tags intentionally differ from the controller image's `on-pr-<sha>` and
`<revision>` tags so the chart copy cannot overwrite the controller image. Configure registry
retention for the chart-specific PR tags and the SemVer `-pr.*` tags; the task does not provide
registry-side tag expiry for its SemVer chart path.

## Consumer reference

The public `rosa-seaplane` repo vendors Helm dependencies as committed `Chart.lock`/`.tgz` archives
(for example
[`argocd/config/shared/karpenter/Chart.yaml`](https://github.com/openshift-online/rosa-seaplane/blob/main/argocd/config/shared/karpenter/Chart.yaml)
and
[`argocd/config/regional-cluster/thanos-operator/Chart.yaml`](https://github.com/openshift-online/rosa-seaplane/blob/main/argocd/config/regional-cluster/thanos-operator/Chart.yaml)).
The chart is stored as tags on the component repository (`oci://<IMAGE>:<version>`), not as
`oci://<tenant>/<chart-name>`. After a successful `main` PipelineRun, take the version from the
tag in its `IMAGE_URL` result. Helm OCI tags encode `+` as `_`; convert that underscore back to
`+` in the `--version` value. Pull and vendor with:

```bash
helm pull oci://quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-kube-applier --version 0.1.42+abcdef0
```

`0.1.42+abcdef0` is an illustrative version from the disposable local-registry round trip; it is
not a Quay publication or a Konflux build result. Commit the downloaded `kube-applier-<version>.tgz`
(and `Chart.lock` if the wrapper uses `helm dependency update`) following the consumer repository's
dependency-lock checks. Helm's usual Chart.yaml OCI form (`repository` = tenant parent, `name` =
chart basename) does not match this push path.

## Konflux and registry onboarding

This change adds repository-side PipelineRuns only; it does not create or modify Konflux or Quay
resources. Before enabling the pipeline, the owning team must verify or configure:

- The existing `rosa-tenant` Konflux namespace, Application/Component, Pipelines-as-Code GitHub
  integration, and `build-pipeline-rosa-seaplane-kube-applier` service account are active for this
  repository.
- Chart PipelineRuns keep the same Application/Component labels for PaC, but set
  `pipelines.appstudio.openshift.io/type: chart` rather than `build`. Integration Service only
  snapshots `type: build` runs. The chart artifact is Helm OCI, not a container image, so a
  `build` label would feed it into Enterprise Contract. The controller image PipelineRuns remain
  `type: build` and are the ones that create Snapshots.
- The existing component image repository remains
  `quay.io/redhat-user-workloads/rosa-tenant/rosa-seaplane-kube-applier`. Chart SemVer tags and the
  `chart-on-pr-<sha>` / `chart-<sha>` traceability tags are written here. They must not collide
  with the controller image tags published by the existing image PipelineRuns.
- Registry retention is agreed for temporary pull-request artifacts. Both the `chart-on-pr-*`
  traceability tags and the SemVer `0.1.0-pr.*` tags are distinct from main tags but remain in the
  registry until its cleanup policy removes them.

No consumer change is included here. Once a main PipelineRun has published a chart tag, a consumer
chart can pull that version and vendor the archive through its existing dependency-lock workflow.

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
