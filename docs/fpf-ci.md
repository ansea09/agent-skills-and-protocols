# FPF Work Guide CI

The `FPF Work Guide` GitHub Actions workflow runs on pushes to main and
codex branches, pull requests to main, and manual dispatch. It checks the
public FPF skill, protocol artifacts, pinned format-validator regressions,
Bash/PowerShell lifecycle fixtures and plugin/source parity on Ubuntu 24.04.
PowerShell coverage is required rather than silently skipped.

Validation dependencies are pinned in scripts/requirements-skill-validation.txt.
The checkout action is commit-pinned, credentials are not persisted, the token
is read-only, and the workflow needs no repository secrets. Dependencies are
installed in a disposable runner directory, not inside the checkout.

Passing CI does not establish native macOS/Windows execution, live GitHub
refresh, answer quality, or the private Suite updater/LaunchAgent behavior.
Private integration tests remain local and their results must be reported
separately. This workflow does not enforce branch protection; maintainers must
check the results for the exact PR revision before merging.
