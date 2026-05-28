# Codex Skills and Protocols

Русская версия README для репозитория с installable Codex skills, plugin packages и FPF-backed protocol docs.

Используйте этот репозиторий, если хотите:

- установить reusable Codex skill;
- установить skill как Codex plugin;
- посмотреть, как skill упакован перед использованием;
- открыть issue или PR по установке, документации или portability;
- адаптировать публичный skill под свой workflow без копирования приватного локального состояния.

English version: [`README.md`](README.md)

## Что можно установить

| Skill | Что делает | Когда использовать | С чего начать |
| --- | --- | --- | --- |
| [`fpf-work-guide`](skills/fpf-work-guide/) | Повышает качество ответов LLM за счёт актуального FPF-контекста и Codex FPF-протоколов, которые проверяются перед содержательной работой. | FPF-backed reasoning, планирование, review, coding и source-backed answers. | [`skills/fpf-work-guide/README.md`](skills/fpf-work-guide/README.md) или [`plugins/fpf-work-guide`](plugins/fpf-work-guide/) |
| [`doc-to-md`](skills/doc-to-md/) | Конвертирует trusted local documents в Markdown через MarkItDown, с optional PDF audit bundles и optional OCR preprocessing. | Локальная конвертация документов, textbook-like PDF audit, OCR для scanned PDF, Markdown intermediate перед анализом. | [`skills/doc-to-md/README.md`](skills/doc-to-md/README.md) или [`plugins/doc-to-md`](plugins/doc-to-md/) |

Полный список skills: [`skills-index.md`](skills-index.md).

## Самый простой способ установки

Если вы не хотите вручную разбираться с командами, используйте prompt-first guide:

[`docs/install-plugins-for-nontechnical-users.md`](docs/install-plugins-for-nontechnical-users.md)

Это инструкция на русском языке. Она даёт один готовый prompt для Codex. Codex сам проверит вашу среду, попросит разрешения на установку и покажет итог.

Рекомендуемый выбор для большинства пользователей: установить только `fpf-work-guide`.

`doc-to-md` устанавливайте дополнительно только если вам нужна конвертация PDF, Word, Excel, PowerPoint, HTML, CSV, JSON, XML или ZIP-файлов в Markdown.

## Установка через plugin

Plugin installation - основной способ распространения skills для других пользователей.

Репозиторий содержит локальный plugin marketplace:

```text
.agents/plugins/marketplace.json
```

Доступные plugin packages:

- [`plugins/fpf-work-guide`](plugins/fpf-work-guide/) - plugin package для публичного `fpf-work-guide` skill.
- [`plugins/doc-to-md`](plugins/doc-to-md/) - plugin package для публичного `doc-to-md` skill.

Если ваш Codex поддерживает repo-local plugin marketplace discovery, подключите marketplace из этого репозитория. Для нетехнической установки используйте готовый prompt из [`docs/install-plugins-for-nontechnical-users.md`](docs/install-plugins-for-nontechnical-users.md).

## Ручная установка

Ручная установка копирует staged public skill в директорию, из которой ваш agent runtime читает skills.

Recommended user-scoped Codex target:

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

Для legacy/current local Codex setups, которые всё ещё читают skills из `${CODEX_HOME:-$HOME/.codex}/skills`, а также для Claude Code, WSL и нестандартных путей используйте подробную инструкцию:

[`docs/install.md`](docs/install.md)

## Поддержка платформ

`fpf-work-guide`:

- основной поддерживаемый путь: Codex на macOS;
- Windows PowerShell/CMD path реализован, но пока считается experimental/unverified до отдельной Windows validation lane;
- WSL Bash path возможен;
- для fresh refresh нужен `git` и доступ к GitHub.

`doc-to-md`:

- основной поддерживаемый путь: Codex на macOS arm64;
- runtime не входит в plugin и собирается локально;
- Windows native сейчас unsupported;
- WSL candidate/unsupported;
- macOS на другой архитектуре требует проверки runtime profile.

## Если что-то не установилось

Откройте issue или PR, если столкнулись с:

- ошибкой установки;
- непонятной диагностикой;
- portability-проблемой на другой ОС, shell или agent runtime;
- ошибкой в документации;
- предложением по адаптации skill к реальному workflow без добавления private local state в public artifact.

В issue укажите:

- имя skill или plugin;
- ОС и runtime;
- путь установки;
- команду или prompt, который вы запускали;
- итоговый diagnostic output или warning.

Для `fpf-work-guide` также укажите, работал ли skill с fresh data или с current cached copy, если это было показано в diagnostic output.

## Проверка перед публикацией изменений

Перед публикацией или передачей изменений запустите structural checks:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

Подробнее: [`docs/validation.md`](docs/validation.md).

## Карта репозитория

| Path | Что это | Кто обычно читает |
| --- | --- | --- |
| [`.agents/`](.agents/) | Machine-readable Codex agent configuration. Сейчас содержит repo-local plugin marketplace metadata. | Codex/plugin tooling и maintainers. |
| [`docs/`](docs/) | Installation docs, validation docs, architecture notes, ADRs, process models и examples. | Users, reviewers, maintainers. |
| [`plugins/`](plugins/) | Installable Codex plugin packages с публичными skills. | Пользователи plugin installation и maintainers packaging. |
| [`protocols/`](protocols/) | FPF-backed response protocol definitions, routing rules, checklists, SOPs и templates. | Пользователи, которые хотят смотреть protocol internals. |
| [`scripts/`](scripts/) | Validation, promotion, drift-check и release-gate scripts. | Maintainers и contributors. |
| [`skills/`](skills/) | Public staged skill source. Это reviewable source, а не обязательно active local runtime copy. | Пользователи ручной установки и contributors. |
| [`README.md`](README.md) | English entrypoint. | Everyone. |
| [`README.ru.md`](README.ru.md) | Русский entrypoint. | Russian-speaking users. |
| [`registry.yaml`](registry.yaml) | Canonical file registry и protocol routing anchors. | Maintainers и protocol tooling. |
| [`skills-index.md`](skills-index.md) | Human-readable inventory staged skills и runtime notes. | Users и maintainers. |

Local-only state directories вроде `.fpf-update/` могут появляться в рабочем checkout, но они intentionally ignored и не должны публиковаться как public skill или plugin content.

## Artifact boundary

Staged public copy в `skills/` - это не то же самое, что installed operational copy в `$HOME/.agents/skills`, `${CODEX_HOME:-$HOME/.codex}/skills` или другой runtime-директории агента.

Plugin packages в `plugins/` включают только public skill source. Они не должны содержать personal launchers, LaunchAgents, session-start hooks, workspace jobs, cache, logs, local state, private overlays, private local policy files, runtime venvs, OCR binaries или generated outputs.

Перед packaging, redistribution или review skill artifacts используйте:

[`docs/skill-artifact-model.md`](docs/skill-artifact-model.md)

Когда обновляете public staged skills из local operational skills, используйте:

[`docs/workflows/promote-local-skills.md`](docs/workflows/promote-local-skills.md)

## License

Этот репозиторий распространяется под [`MIT License`](LICENSE), если явно не указано другое.

Third-party tools и dependencies сохраняют свои собственные licenses. Перед redistribution optional runtimes или dependency bundles проверяйте skill-specific third-party notices.
