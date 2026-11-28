# setup-mortise

A GitHub Action that installs `mortise`, the command line tool of
[Mortise](https://github.com/mortise-dev/mortise), from a release. It downloads the archive for the runner,
checks its SHA-256 against the sums file of the release, and puts `mortise` on `PATH`. It needs no Rust
toolchain and takes a few seconds.

`mortise check` reads a Laravel app that uses
[`nwidart/laravel-modules`](https://github.com/nWidart/laravel-modules), without PHP, and fails the job
when a boundary rule breaks. `mortise push` sends one read of the app to
[Mortise Cloud](https://mortisecloud.com).

## Use

```yaml
# .github/workflows/mortise.yml
name: Mortise

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  mortise:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: mortise-dev/setup-mortise@v1

      - name: Send the snapshot to Mortise Cloud
        run: mortise push .
        env:
          MORTISE_TOKEN: ${{ secrets.MORTISE_TOKEN }}

      - name: Check the boundary rules
        run: mortise check . --format github
```

`fetch-depth: 0` gives `mortise push` the full history. Full history gives commits per module and lets Mortise fill
past history. A depth of 1 is faster and leaves both out.

`mortise push` needs a token of [Mortise Cloud](https://mortisecloud.com/push?utm_source=setup-mortise-readme&utm_medium=referral) in the secret `MORTISE_TOKEN`.
Without the cloud, leave that step out: `mortise check` needs no token.

### With coverage

Coverage comes from a clover report, so the tests run first. The checkout keeps `fetch-depth: 0`, for the same reason:

```yaml
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          coverage: pcov

      - run: composer install --no-interaction --no-progress
      - run: cp .env.example .env && php artisan key:generate
      - run: vendor/bin/phpunit --coverage-clover build/coverage/clover.xml

      - uses: mortise-dev/setup-mortise@v1

      - name: Send the snapshot to Mortise Cloud
        run: mortise push . --coverage build/coverage/clover.xml
        env:
          MORTISE_TOKEN: ${{ secrets.MORTISE_TOKEN }}

      - name: Check the boundary rules
        run: mortise check . --coverage build/coverage/clover.xml --format github
```

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `version` | `latest` | The release to install: `latest`, or a tag such as `v0.3.0` (`0.3.0` works too) |
| `token` | `${{ github.token }}` | A token for the GitHub API. It is used only to find the newest release when `version` is `latest`. Without one the API allows 60 calls an hour per address |

Pin a version for builds that must not change on their own:

```yaml
      - uses: mortise-dev/setup-mortise@v1
        with:
          version: v0.3.0
```

## Outputs

| Output | Meaning |
|---|---|
| `version` | The tag of the installed release, such as `v0.3.0` |

## Runners

| Runner | Archive |
|---|---|
| Linux, x64 (`ubuntu-latest`) | `mortise-vX.Y.Z-linux-x86_64.tar.gz`, static |
| Linux, arm64 (`ubuntu-24.04-arm`) | `mortise-vX.Y.Z-linux-arm64.tar.gz`, static |
| macOS, Apple silicon (`macos-latest`) | `mortise-vX.Y.Z-macos-arm64.zip`, signed and notarized |
| Windows, x64 (`windows-latest`) | `mortise-vX.Y.Z-windows-x64.zip` |

On another runner, such as macOS on Intel, the action fails and says so. Install the tool there with
`cargo install --locked mortise-cli`.

## What it checks

1. It downloads the archive and `Mortise-vX.Y.Z-SHA256SUMS.txt` from the release of
   [mortise-dev/mortise](https://github.com/mortise-dev/mortise/releases).
2. It compares the SHA-256 of the archive with the archive's line in the sums file. A missing line or
   another sum fails the step, and nothing goes on `PATH`.
3. It unpacks the archive into the temporary folder of the runner and runs `mortise --version`, which
   must print the version of the release.
4. It adds that folder to `PATH` for the later steps of the job.

The sums file and the archive come from the same release, so the check catches a broken or changed
download, not a changed release. Pin the action to a commit to trust only code you have read.

## Licence

MIT, see `LICENSE`.
