# Prow build root

`ci/Containerfile` provides the Go toolchain and build utilities for the Prow
`src` image used by `lint.sh`, `unit-tests.sh`, and `verify.sh`. It uses the
same digest-pinned Hummingbird FIPS Go builder as the production image. That
builder already includes Bash, Git, Make, GCC, and GNU findutils, so no additional
package installation is needed for the CI workflows, including race tests.
Its Go toolchain satisfies all three modules' Go 1.26.3 minimum, and its FIPS
settings are inherited unchanged. The production `Containerfile` remains
independent.

Renovate discovers both Containerfiles through the Dockerfile manager; the
existing Dockerfile digest-update rules also apply to the CI builder reference.

The configuration in `openshift/release` selects this file through
`build_root.project_image.dockerfile_path`, matching rosa-seaplane's setup.
Merge this repository's image definition before enabling that configuration.
Keep `.ci-operator.yaml` during the transition so jobs still configured with
`build_root.from_repository` continue to work. Once the release configuration
is migrated, that legacy selector is no longer used by these jobs.

The image's cache directories are writable by arbitrary OpenShift UIDs.
ci-operator clones source under `/go/src` and sets `GOPATH=/go`; the module
cache is explicitly outside that source tree. The CI scripts retain their
isolated temporary caches. No cross-run cache persistence or measured speedup
is implied by this setup.

The `make helm-test` target lints, renders, and packages the source chart. It requires a
Helm CLI and is run separately from the Go build-root scripts.
