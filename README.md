# Docker Bump GitHub Action

A [GitHub action](https://docs.github.com/actions) that can be used to trigger a GitHub Actions workflow or GitHub App webhook whenever a target Docker image is not up-to-date with its dependent base image. The canonical scenario is to trigger a GitHub Actions workflow to run that will rebuild a Docker image whenever its base image has been updated. But you're free to define whatever logic you want to have executed when this out-of-date condition occurs.

This is implemented by using the [`repository-dispatch` GitHub action](https://github.com/peter-evans/repository-dispatch) to create [`repository_dispatch`](https://docs.github.com/rest/repos/repos#create-a-repository-dispatch-event) events. These events can then be responded to by GitHub Actions workflow or GitHub Actions.

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
          base-image-name: alpine:latest
```

Add the following in the workflow which builds your Docker image:

```yml
on:
  repository_dispatch:
    types: [base-image-update]
```

See a working example of these workflows at [mthalman/docker-bump-action-example](https://github.com/mthalman/docker-bump-action-example).

### Action inputs

| Name | Description | Default |
| --- | --- | --- |
| `target-image-name` | (**required**) Name of the image to check. | |
| `base-image-name` | (**required**) Name of the base image the target image is based on. | |
| `arch` | Default architecture of the image | `amd64` |
| `repository` | The full name of the repository to send the dispatch. | `${{ github.repository }}` |
| `event-type` | A custom webhook event name. | `base-image-update` |
| `token` | An access token with the appropriate permissions. See [Token](#token) for further details. | `${{ github.token }}` |

## OS Support

Support is limited to Linux container images only.

## Token

In order to create the [`repository_dispatch`](https://docs.github.com/rest/repos/repos#create-a-repository-dispatch-event) events, the action requires access to the repo via a token.

The default `GITHUB_TOKEN` token can only be used if you are dispatching to the same repository that the workflow is executing in.

To dispatch to a separate repository you must create a [personal access token (PAT)](https://docs.github.com/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) with the `repo` scope and [store it as a secret](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions). If you will be dispatching to a public repository then you can use the more limited `public_repo` scope.

You can also use a fine-grained personal access token (beta). It needs the following permissions on the target repositories:

* `contents: read & write`
* `metadata: read only` (automatically selected when selecting the contents permission)

## Troubleshooting

### Error: `Resource not accessible by integration`

This error occurs when using the `GITHUB_TOKEN` token (the default token value) and not having write permissions for the repo. Go to your GitHub repo's Settings page at `https://github.com/<owner>/<repo>/settings/actions` and ensure that `Read and write permissions` is set for Workflow permissions.

### Error: `Repository not found, OR token has insufficient permissions.`

This error occurs when the [personal access token (PAT)](https://docs.github.com/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) is not configured with appropriate permissions. See [Token](#token) for configuration details.
