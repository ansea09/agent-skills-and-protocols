# Agent Skills and Protocols

English version: [`README.md`](README.md)

Этот репозиторий публикует reusable skills для Codex, plugin packages для Codex, install profiles для Claude Code и документацию по FPF-backed protocols.

Используйте его, если хотите:

- установить публичный skill для Codex;
- установить Codex plugin, который включает публичный skill;
- установить Claude Code profile для поддерживаемого публичного skill;
- понять, чем отличаются skill source, plugin package, runtime и локальное состояние;
- предложить правку без публикации приватных локальных настроек.

## Что установить

| Задача | Что установить | С чего начать |
| --- | --- | --- |
| Чтобы Codex проверял актуальный FPF-контекст и применял FPF-backed protocols перед содержательной работой | `fpf-work-guide` | [`skills/fpf-work-guide/README.md`](skills/fpf-work-guide/README.md) |
| Чтобы конвертировать локальные документы в Markdown | `doc-to-md` | [`skills/doc-to-md/README.md`](skills/doc-to-md/README.md) |
| Чтобы транскрибировать локальные speech audio в Markdown bundles | `speech-to-md` | [`skills/speech-to-md/README.md`](skills/speech-to-md/README.md) |
| Чтобы установить skill через упаковку Codex plugin | Codex plugin package | [`plugins/`](plugins/) |
| Чтобы использовать поддерживаемый публичный skill в Claude Code | Claude Code source-only profile | [`claude-code/`](claude-code/) |

Публичные skills:

| Skill | Что делает |
| --- | --- |
| [`fpf-work-guide`](skills/fpf-work-guide/) | Проверяет или обновляет локальный FPF-контекст и применяет FPF-backed protocols перед содержательной работой Codex. |
| [`doc-to-md`](skills/doc-to-md/) | Конвертирует trusted local files в Markdown через MarkItDown, с optional PDF audit bundles и optional OCR preprocessing. |
| [`speech-to-md`](skills/speech-to-md/) | Конвертирует trusted local speech recordings или готовые transcripts в Markdown transcript bundles для LLM analysis. |

Полный список: [`skills-index.md`](skills-index.md).

## Самый простой путь

Большинству пользователей Codex стоит начать с `fpf-work-guide`.

Если ваш Codex поддерживает repo-local plugin marketplace discovery, используйте plugin package:

```text
.agents/plugins/marketplace.json
```

Доступные plugin packages:

- [`plugins/fpf-work-guide`](plugins/fpf-work-guide/)
- [`plugins/doc-to-md`](plugins/doc-to-md/)
- [`plugins/speech-to-md`](plugins/speech-to-md/)

Если plugin marketplace discovery недоступен, установите skill вручную.

Для нетехнической установки через готовый prompt используйте:

[`docs/install-plugins-for-nontechnical-users.md`](docs/install-plugins-for-nontechnical-users.md)

## Ручная установка для Codex

Ручная установка копирует public skill source в директорию, из которой ваш local agent runtime читает skills.

Рекомендуемая user-scoped директория:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Установить `fpf-work-guide`:

```bash
cp -R skills/fpf-work-guide "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
```

Установить `doc-to-md` и собрать core runtime:

```bash
cp -R skills/doc-to-md "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/doc-to-md/scripts/install.sh"
```

Установить `speech-to-md` и command shim:

```bash
cp -R skills/speech-to-md "$CODEX_SKILLS_TARGET/"
bash "$CODEX_SKILLS_TARGET/speech-to-md/scripts/install.sh"
speech-to-md --doctor
```

Для локального ASR нужны установленные пользователем `whisper-cli` и model.
Для MP3/M4A и нормализации audio containers также нужен локальный `ffmpeg`;
public skill не включает эти runtime binaries и модели.

Для legacy Codex setups, которые всё ещё читают skills из `${CODEX_HOME:-$HOME/.codex}/skills`, а также для WSL и нестандартных путей используйте [`docs/install.md`](docs/install.md).

## Установка в Claude Code

Claude Code не использует Codex plugins. Для Claude Code используйте source-only install profiles из [`claude-code/`](claude-code/).

Текущий профиль:

- [`claude-code/fpf-work-guide`](claude-code/fpf-work-guide/) устанавливает Claude Code slash commands и subagent, которые вызывают публичный `fpf-work-guide` skill.

## Что устанавливается локально

В этом репозитории разделены source, packaging, runtime dependencies и generated files.

| Слой | Примеры | Публикуется здесь? |
| --- | --- | --- |
| Public skill source | `skills/fpf-work-guide`, `skills/doc-to-md`, `skills/speech-to-md` | Да |
| Codex plugin package | `plugins/fpf-work-guide`, `plugins/doc-to-md`, `plugins/speech-to-md` | Да |
| Claude Code profile | `claude-code/fpf-work-guide` | Да |
| Runtime dependencies | Python virtual environments, installed command shims, OCR tools, ASR models, external ASR binaries | Нет |
| Local state and cache | `.fpf-update`, FPF caches, logs | Нет |
| Generated outputs | Markdown files, OCR PDFs, audit bundles | Нет |
| Private local policy | Personal defaults, private overlays, local launchers | Нет |

Подробная модель: [`docs/skill-artifact-model.md`](docs/skill-artifact-model.md).

## Если что-то не работает

Откройте issue или PR, если столкнулись с:

- ошибкой установки;
- непонятной диагностикой;
- portability-проблемой на другой ОС, shell или agent runtime;
- ошибкой в документации;
- необходимой адаптацией под реальный workflow без публикации private local state.

Укажите:

- имя skill или plugin;
- ОС и runtime;
- путь установки;
- команду, которую запускали;
- diagnostic output или warning.

Для `fpf-work-guide` также укажите, использовались fresh data или current cached copy, если это было показано в диагностике.

## Документация для maintainers

Перед публикацией или review изменений используйте:

- [`docs/install.md`](docs/install.md)
- [`docs/validation.md`](docs/validation.md)
- [`docs/skill-artifact-model.md`](docs/skill-artifact-model.md)
- [`docs/workflows/promote-local-skills.md`](docs/workflows/promote-local-skills.md)

Перед передачей изменений запустите structural checks:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

Для source/plugin release `doc-to-md` также используйте release gate, описанный в [`docs/validation.md`](docs/validation.md).

## Карта репозитория

| Path | Что это |
| --- | --- |
| [`.agents/`](.agents/) | Repo-local metadata для Codex plugin marketplace. |
| [`claude-code/`](claude-code/) | Source-only install profiles для Claude Code. |
| [`docs/`](docs/) | Installation, validation, artifact model, ADRs, process models и workflows. |
| [`plugins/`](plugins/) | Codex plugin packages, которые включают public skill source. |
| [`protocols/`](protocols/) | FPF-backed protocol definitions, routing rules, checklists, SOPs и templates. |
| [`scripts/`](scripts/) | Validation, promotion, drift-check и release-gate scripts. |
| [`skills/`](skills/) | Public staged skill source. |
| [`registry.yaml`](registry.yaml) | Canonical registry и protocol routing anchors. |
| [`skills-index.md`](skills-index.md) | Human-readable inventory публичных staged skills. |

## License

Репозиторий распространяется под [MIT License](LICENSE), если явно не указано другое.

Third-party tools и dependencies сохраняют свои собственные licenses. Перед redistribution optional runtimes или dependency bundles проверяйте skill-specific third-party notices.
