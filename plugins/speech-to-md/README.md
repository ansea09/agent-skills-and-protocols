# Speech To Md Plugin

This plugin distributes the public `speech-to-md` Codex skill as a source
artifact. The bundled skill can package existing transcripts and can run a local
`whisper.cpp` transcription workflow when `whisper-cli` and a model file are
installed by the user.

## What Is Included

- `skills/speech-to-md/README.md`
- `skills/speech-to-md/SKILL.md`
- `skills/speech-to-md/agents/`
- `skills/speech-to-md/scripts/`
- `skills/speech-to-md/references/`

## What Is Not Included

This plugin intentionally does not include local runtime state or heavy ASR
artifacts:

- ASR model files;
- `whisper.cpp` binaries, `ffmpeg`, or Homebrew packages;
- cloud credentials or API keys;
- private audio recordings, transcripts, generated bundles, cache, logs, or
  temporary files;
- personal local policy files or private overlays.

## Runtime Contract

After installing the plugin, install the command shim from the installed skill
directory:

```bash
bash "${CODEX_HOME:-$HOME/.codex}/skills/speech-to-md/scripts/install.sh"
```

Then check readiness:

```bash
speech-to-md --doctor
```

Transcript import works without ASR:

```bash
speech-to-md --transcript transcript.txt --source-audio recording.mp3 -o recording-audio-bundle
```

Local ASR requires `whisper-cli` and a user-provided model:

```bash
export SPEECH_TO_MD_WHISPER_CPP_MODEL="/absolute/path/to/ggml-model.bin"
speech-to-md recording.mp3 -o recording-audio-bundle
```

M4A/AAC/MP4 and other container normalization paths require local `ffmpeg`:

```bash
export SPEECH_TO_MD_FFMPEG_BIN="/absolute/path/to/ffmpeg"
speech-to-md recording.m4a -o recording-audio-bundle --audio-normalization auto
```

## Support Boundary

Trusted local macOS/Codex usage is the first maintained path. Native Windows
support, cloud transcription, diarization, speaker identity, translation,
hosted ingestion, and remote URL fetching are not part of this first public
runtime.

## Validation

From the repository root:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

Smoke check the bundled script:

```bash
python3 skills/speech-to-md/scripts/speech-to-md --doctor --json
python3 skills/speech-to-md/scripts/regression_corpus.py
```
