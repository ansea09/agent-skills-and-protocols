# Установка плагинов для нетехнического пользователя

Этот способ подходит, если вы не хотите вручную разбираться с командами, путями, runtime-зависимостями и проверками. Скопируйте готовый prompt из этого файла в Codex, а Codex сам проверит вашу среду, попросит разрешения на установку и покажет итог.

## Что выбрать

Рекомендуемый вариант для большинства пользователей: установить только `fpf-work-guide`.

`doc-to-md` устанавливайте дополнительно только если вам нужна конвертация локальных PDF, Word, Excel, PowerPoint, HTML, CSV, JSON, XML или ZIP-файлов в Markdown.

Важно про платформы:

- `fpf-work-guide`: основной путь поддержки - Codex на macOS. Windows PowerShell/CMD path реализован, но пока считается experimental/unverified до отдельной проверки на Windows. WSL Bash path возможен.
- `doc-to-md`: основной поддерживаемый путь - Codex на macOS arm64. Windows native не поддерживается. WSL считается candidate/unsupported. macOS на другой архитектуре требует проверки runtime profile.

## Что будет делать Codex

Codex должен будет попросить разрешение, если ему понадобится:

- скачать репозиторий из GitHub;
- записать настройки plugin marketplace в локальную конфигурацию Codex;
- установить plugin в локальный Codex cache;
- для `doc-to-md` собрать локальный runtime;
- записать локальные wrappers или state-файлы в пользовательские директории.

Плагины не должны устанавливать auto-upgrade, private overlays, runtime venv, cache или generated output из репозитория.

## Готовый prompt

Скопируйте весь блок ниже и отправьте его в Codex:

```text
Установи мне Codex plugin из публичного репозитория:

https://github.com/ansea09/agent-skills-and-protocols

Сначала уточни, что я хочу установить:

1. Рекомендуемый вариант:
   установить только fpf-work-guide.

2. Дополнительный вариант:
   установить doc-to-md тоже, только если мне нужна конвертация PDF/DOCX/XLSX/PPTX/HTML/CSV/JSON/XML/ZIP в Markdown.
   Важно: doc-to-md сейчас поддерживается только для Codex на macOS arm64. Windows native не поддерживается, WSL считается candidate/unsupported, а macOS на другой архитектуре требует отдельной проверки runtime profile.

3. Если я явно скажу "оба", "all", "fpf-work-guide и doc-to-md" - устанавливай оба.

Важно про поддержку:

- fpf-work-guide:
  - основной поддерживаемый путь: Codex на macOS;
  - Windows PowerShell/CMD path реализован, но пока experimental/unverified;
  - WSL Bash path возможен;
  - требует Git для fresh refresh.

- doc-to-md:
  - основной поддерживаемый путь: Codex на macOS arm64;
  - требует отдельной сборки локального runtime;
  - Windows native сейчас unsupported;
  - WSL candidate/unsupported, не устанавливай runtime без явного подтверждения.

После выбора plugin проверь мою среду:

1. Если это Codex на macOS arm64:
   - fpf-work-guide можно устанавливать;
   - doc-to-md можно устанавливать только если я его выбрала/выбрал.

2. Если это Codex на macOS не-arm64:
   - fpf-work-guide можно устанавливать;
   - doc-to-md устанавливай только после проверки, что есть поддерживаемый runtime profile для моей архитектуры.

3. Если это Windows:
   - fpf-work-guide можно попробовать установить как experimental/unverified;
   - doc-to-md не устанавливай.

4. Если это WSL:
   - fpf-work-guide можно попробовать установить через Bash path;
   - doc-to-md не устанавливай без отдельного явного подтверждения.

5. Если это другая среда:
   - остановись и объясни, какой путь поддерживается.

Дальше выполни установку:

1. Создай локальную папку для plugin marketplace.

   На macOS или WSL:
   ~/CodexPlugins/agent-skills-and-protocols

   На Windows PowerShell:
   ~/CodexPlugins/agent-skills-and-protocols

   Используй path syntax текущей ОС. Не запускай Bash-only команды в Windows native.

2. Если репозиторий ещё не скачан, скачай его.

   На macOS или WSL:
   git clone https://github.com/ansea09/agent-skills-and-protocols.git ~/CodexPlugins/agent-skills-and-protocols

   На Windows PowerShell используй эквивалентный путь в профиле пользователя.

3. Если репозиторий уже скачан, обнови его.

   На macOS или WSL:
   git -C ~/CodexPlugins/agent-skills-and-protocols pull --ff-only

   На Windows PowerShell используй эквивалентный путь в профиле пользователя.

4. Подключи repo как локальный Codex marketplace.

   На macOS или WSL:
   codex plugin marketplace add ~/CodexPlugins/agent-skills-and-protocols

   На Windows PowerShell используй эквивалентный путь в профиле пользователя.

5. Установи выбранные plugin:

   Для fpf-work-guide:
   codex plugin add fpf-work-guide@agent-skills-and-protocols

   Для doc-to-md, только если я явно выбрала/выбрал его:
   codex plugin add doc-to-md@agent-skills-and-protocols

6. Проверь установку:
   codex plugin marketplace list
   codex plugin list

7. Если установлен fpf-work-guide:
   - найди путь установленного plugin;
   - на macOS или WSL запусти doctor через Bash:
     bash "<FPF_WORK_GUIDE_PLUGIN_PATH>/skills/fpf-work-guide/scripts/fpf-work-guide-doctor" --write-state
   - на Windows PowerShell запусти doctor через PowerShell:
     powershell -ExecutionPolicy Bypass -File "<FPF_WORK_GUIDE_PLUGIN_PATH>\skills\fpf-work-guide\scripts\fpf-work-guide-doctor.ps1" --write-state
   - на Windows CMD используй bundled CMD wrapper, если это соответствует текущей оболочке:
     "<FPF_WORK_GUIDE_PLUGIN_PATH>\skills\fpf-work-guide\scripts\fpf-work-guide-doctor.cmd" --write-state

8. Если установлен doc-to-md:
   - найди путь установленного plugin;
   - собери локальный runtime:
     bash "<DOC_TO_MD_PLUGIN_PATH>/skills/doc-to-md/scripts/install.sh" --all --hash-locked
   - запусти проверки:
     mdown-doctor --json
     mdown-epub --doctor --json
     mdown-book --doctor --json
     mdown-ocrpdf --doctor --json

9. Покажи мне короткий итог:
   - какой plugin был выбран;
   - установлен ли fpf-work-guide;
   - установлен ли doc-to-md, если был выбран;
   - прошли ли doctors;
   - есть ли warnings;
   - нужно ли перезапустить Codex или открыть новую сессию.

Правила безопасности:

- Не изменяй системные файлы без моего разрешения.
- Если нужна сеть, установка пакетов, запись в ~/.codex, ~/.local или другая операция вне текущей папки, сначала попроси разрешение.
- Не устанавливай auto-upgrade.
- Не добавляй private overlays.
- Не копируй venv/cache/output из репозитория.
- Не устанавливай doc-to-md на Windows native.
- Не называй Windows support для fpf-work-guide полностью проверенным: он реализован, но пока experimental/unverified до прохождения Windows validation lane.
```

## Ожидаемый результат

После установки Codex должен показать короткий итог:

- какой plugin был выбран;
- установлен ли `fpf-work-guide`;
- установлен ли `doc-to-md`, если вы его выбрали;
- прошли ли проверки;
- какие warnings остались;
- нужно ли перезапустить Codex или открыть новую сессию.

Если установка не удалась, скопируйте итоговое сообщение Codex и откройте issue в репозитории. Укажите вашу операционную систему, какой plugin вы выбрали и текст ошибки или warning.
