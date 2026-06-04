# Python Profile Policy

Use this reference before claiming that `doc-to-md` works on a Python minor
version, architecture, or platform that is not already listed in the support
matrix.

## Profile Identity

A runtime profile is identified by:

```text
<os>-<architecture>-<python-tag>
```

Examples:

```text
macos-arm64-py313
macos-intel-py312
linux-x86_64-py313
```

The Python tag is part of the profile because hash-locked installs depend on
the Python ABI, such as `cp312`, `cp313`, or a later ABI tag. Do not treat one
Python minor version as evidence for another minor version.

## Support Levels

| Level | Meaning | Public claim allowed |
| --- | --- | --- |
| Supported hash-locked profile | Matching `requirements-*.hashes.txt` files exist for the claimed components, install succeeds with `--require-hashes`, and doctors/selftests/regressions have passed for that profile. | May be listed as supported with `--hash-locked`. |
| Supported normal pinned install | Exact pins install without `--require-hashes`, doctors/selftests/regressions have passed, and the support matrix explicitly lists the profile or environment as supported for normal install. | May be listed as supported without hash reproducibility. |
| Candidate / unverified | The profile may resolve with pip, but wheel availability, doctors, selftests, or regression output have not been reviewed. | Do not claim support; describe it as candidate or unverified. |
| Unsupported | The profile is known not to work or requires a different runtime design. | Do not recommend it except to explain the boundary. |

## Current Profile Register

| Profile | Support level | Components | Notes |
| --- | --- | --- | --- |
| `macos-arm64-py313` | Supported hash-locked profile | core, book, OCR | Maintained public release profile. |
| `macos-intel-py312` | Supported hash-locked profile | core, book | OCR hash-locked support is not published for Intel macOS. |
| `macos-arm64-py312` | Candidate / unverified | none claimed | Add only after resolver, hashes, doctors, selftests, and regressions pass. |
| `macos-arm64-py314` | Candidate / unverified | none claimed | Newer Python minor releases often wait on compiled wheels. |
| `macos-intel-py313` | Candidate / unverified | none claimed | `onnxruntime==1.26.0` did not publish a compatible Intel macOS wheel in the checked set. |
| `macos-intel-py314` | Candidate / unverified | none claimed | Do not claim until the dependency graph is reviewed for that ABI. |
| `linux-x86_64-py312` / `linux-x86_64-py313` | Candidate / unverified | none claimed | WSL/Linux needs separate profile generation and validation. |

The `core` component includes the standard `mdown` conversion path and the
separate `mdown-epub` EPUB LLM-analysis bundle command. Do not list EPUB bundle
as a separate profile component unless it gains its own runtime or lockfile.

## Installer Policy

`--hash-locked` must fail closed when the matching profile hash file is absent.
It must not fall back to another Python minor version, another architecture, or
the generic requirements file.

Normal pinned install may use generic exact pins when a profile-specific
requirements file is absent, except where the installer has a known blocker for
that environment. Treat that path as candidate/unverified unless the support
matrix explicitly says otherwise.

## Promotion Procedure

To promote a Python profile:

1. Pick an explicit profile name with OS, architecture, and Python tag.
2. Verify that all claimed Python packages resolve for that target.
3. Generate profile-specific hash files for the claimed components.
4. Build the runtime from those files with `--hash-locked`.
5. Run doctors for all claimed components.
6. Run core selftest and regression corpus.
7. Run at least one real sample conversion for each affected workflow.
8. Update this file, `references/support-matrix.md`, `SKILL.md` frontmatter,
   `references/publishing.md`, and the architecture ADR.

Do not promote a profile only because normal `pip install` happens to succeed.
