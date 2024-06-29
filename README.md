# Docker Bump GitHub Action

A [GitHub action](https://docs.github.com/actions) that can be used to trigger a GitHub Actions workflow or GitHub App webhook whenever a target Docker image is not up-to-date with its dependent base image. The canonical scenario is to trigger a GitHub Actions workflow to run that will rebuild a Docker image whenever its base image has been updated. But you're free to define whatever logic you want to have executed when this out-of-date condition occurs.

This is implemented by using the [`repository-dispatch` GitHub action](https://github.com/peter-evans/repository-dispatch) to create [`repository_dispatch`](https://docs.github.com/rest/repos/repos#create-a-repository-dispatch-event) events. These events can then be responded to by a GitHub Actions workflow or GitHub App webhook.

It sounds complicated but it's actually easy to set up.

## Usage

Dispatch an event to the current repository whenever `ghcr.io/mthalman/docker-bump-action-example:latest` is not up-to-date with `alpine:latest`.

```yml
name: Monitor for Base Image Update

on:
  schedule:
  - cron: "0 2 * * *"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: mthalman/docker-bump-action@v0
        with:
          target-image-name: ghcr.io/mthalman/docker-bump-action-example:latest
          dockerfile: Dockerfile
```

Add the following in the workflow which builds your Docker image:

```yml
on:
  repository_dispatch:
    types: [base-image-update]
```

See a working example of these workflows at [mthalman/docker-bump-action-example](https://github.com/mthalman/docker-bump-action-example).

See [Examples](#examples) below for more usage patterns.

### Action inputs

| Name | Description | Default |
| --- | --- | --- |
| `target-image-name` |**Required** Name of the image to check. | |
| `base-image-name` | Name of the base image the target image is based on. **Required** when `dockerfile` is not set. See [Image Name Derivation](#base-image-name-derivation).  | |
| `dockerfile` | Path to the Dockerfile from which to derive image names. **Required** when `base-image-name` is not set. See [Image Name Derivation](#base-image-name-derivation). | |
| `base-stage-name` | Name of the stage within the Dockerfile from which to derive the name of the base image. See [Image Name Derivation](#base-image-name-derivation).  | |
| `arch` | Default architecture of the image | `amd64` |
| `repository` | The full name of the repository to send the dispatch. | `${{ github.repository }}` |
| `event-type` | A custom webhook event name. | `base-image-update` |
| `token` | An access token with the appropriate permissions. See [Token](#token). | `${{ github.token }}` |

## OS Support

Support is limited to Linux container images only.

## Token

In order to create the [`repository_dispatch`](https://docs.github.com/rest/repos/repos#create-a-repository-dispatch-event) events, the action requires access to the repo via a token.

The default `GITHUB_TOKEN` token can only be used if you are dispatching to the same repository that the workflow is executing in.

To dispatch to a separate repository you must create a [personal access token (PAT)](https://docs.github.com/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) with the `repo` scope and [store it as a secret](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions). If you will be dispatching to a public repository then you can use the more limited `public_repo` scope.

You can also use a fine-grained personal access token (beta). It needs the following permissions on the target repositories:

* `contents: read & write`
* `metadata: read only` (automatically selected when selecting the contents permission)

## Base Image Name Derivation

The base image name can either be provided explicitly via the `base-image-name` input or can be derived from the content of the Dockerfile specified by the `dockerfile` input. Be sure to examine the log output from the action to verify which image name it is using.

Depending on how you've structured your Dockerfiles (specifically for multi-stage Dockerfiles), the base image name that is derived by the algorithm may not be what you intended. If the base image name is not what you intended, you can override it via the `base-image-name` or `base-stage-name` inputs.

The algorithm for deriving the image names is described below:

1. Find the last stage defined in the Dockerfile.
1. Starting from the last stage, walk the stage hierarchy until the root stage is found.
1. The image name of the root stage is considered the base image name.

## Dispatch Payload

When the repository dispatch occurs, a payload is sent along with it. This payload includes metadata describing the state of the image that resulted in an update being needed. This payload can be retrieved in the workflow that responds to the dispatch via the `client-payload` event. Consuming this payload is completely optional and only necessary if your workflow requires more context regarding the dispatch.

```yaml
name: Build Image
on:
  repository_dispatch:
    types: [base-image-update]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - name: Show Rebuild Info
      if: ${{ github.event.client_payload }}
      run: |
        target="${{ github.event.client_payload.updates[0].targetImageName }}"
        base="${{ github.event.client_payload.updates[0].baseImageName }}"
        echo "Rebuilding $target to be in sync with $base"
```

### Payload Schema

Each object in the `updates` array represents an image that the action has determined requires an update.
Currently the action only supports targeting single images and so this array will always have a single element.
See #3 for support for multiple images.

```json
{
  "updates": [
    {
      "targetImageName": "Name of the target image provided as input to the action",
      "targetImageDigest": "Current digest of the target image",
      "dockerfile": "Relative path of the Dockerfile",
      "baseImageName": "Name of the base image that was either provided as input to the action or derived via other state",
      "baseImageDigest": "Current digest of the base image"
    }
  ]
}
```

## Examples

### Explicitly set base stage name

In this example, the test stage is the last stage listed.
Based on the [algorithm described above](#base-image-name-derivation), the action would start at the last stage and walk the hierarchy until it reached the root stage, which has an image name of `mcr.microsoft.com/dotnet/sdk:latest`.
That's what would be used as the base image name. However, that's not what we want since the actually shipping app image is based on `mcr.microsoft.com/dotnet/runtime:latest`.

```Dockerfile
# Build image
FROM mcr.microsoft.com/dotnet/sdk:latest AS build
<content>

# App image
FROM mcr.microsoft.com/dotnet/runtime:latest AS app
COPY --from=build /app /app

# Test image
FROM build AS test
<content>
```

To configure the action to use `mcr.microsoft.com/dotnet/runtime:latest` as the base image name, the `base-stage-name` input is set to `app`.

```yaml
- uses: mthalman/docker-bump-action@v0
  with:
    target-image-name: ghcr.io/mthalman/docker-bump-action-example:latest
    base-stage-name: app
```

Indicating the base **stage** name rather than the base **image** name can be more convenient because it allows the image name in the Dockerfile to be updated without needing to also change the workflow file.

### Explicitly set base image name

In this example, the base image name used in the Dockerfile is dynamic so the action can't use the Dockerfile as input.

```Dockerfile
ARG BASE_IMAGE
FROM $BASE_IMAGE
<rest of content>
```

Instead, the desired base image name is explicitly provided as input.
Here, the base image name is explicitly set to `alpine:latest`.

```yaml
- uses: mthalman/docker-bump-action@v0
  with:
    target-image-name: ghcr.io/mthalman/docker-bump-action-example:latest
    base-image-name: alpine:latest
```

## Troubleshooting

### Error: `Resource not accessible by integration`

This error occurs when using the `GITHUB_TOKEN` token (the default token value) and not having write permissions for the repo. Go to your GitHub repo's Settings page at `https://github.com/<owner>/<repo>/settings/actions` and ensure that `Read and write permissions` is set for Workflow permissions.

### Error: `Repository not found, OR token has insufficient permissions.`

This error occurs when the [personal access token (PAT)](https://docs.github.com/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) is not configured with appropriate permissions. See [Token](#token) for configuration details.
