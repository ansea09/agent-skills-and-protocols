# Runtime Boundary

`speech-to-md` is source-only by default. The public skill includes wrapper
scripts and bundle rules; it does not ship ASR model files, cloud credentials,
Homebrew packages, Python virtual environments, generated transcripts, or user
audio.

## Supported Source-Level Engine Contract

The first local engine contract is `whisper.cpp`:

- command: `whisper-cli`
- model: user-provided `ggml` model path
- input: trusted local audio file
- optional preprocessor: local `ffmpeg` for audio container normalization
- output consumed by this skill: JSON text segments, plain text transcript, and
  optional VTT timestamps

The CLI dispatches ASR through an explicit engine adapter boundary. The current
public adapter registry contains only `whisper-cpp`. Additional local ASR
engines should be added as adapters only when they can preserve the same bundle
contract. See `extension-boundaries.md` before adding a second engine,
diarization, chunking, or cloud workflows.

Set the model path with:

```bash
export SPEECH_TO_MD_WHISPER_CPP_MODEL="/absolute/path/to/ggml-model.bin"
```

or pass:

```bash
speech-to-md recording.mp3 -o recording-audio-bundle --model /absolute/path/to/ggml-model.bin
```

The wrapper also auto-discovers common model filenames under:

```text
${CODEX_HOME:-$HOME/.codex}/tools/whisper.cpp/models
```

Auto-discovery intentionally uses a quality floor. It considers
`ggml-medium-q8_0.bin`, `ggml-medium.bin`, `ggml-small-q8_0.bin`, and
`ggml-small.bin`; it does not select `tiny` or `base` models automatically.
Pass `--model` for an explicit speed-first test with a lower-quality model.

Set `SPEECH_TO_MD_MODELS_DIR` when models live somewhere else.

The wrapper checks for `whisper-cli` and the model file. It does not install or
download them.

Doctor and bundle manifests record runtime fingerprints for auditability:

- `whisper-cli` path, executable checksum, help/probe output, and local
  `whisper.cpp` source commit when discoverable;
- model path, size, and checksum;
- `ffmpeg` path, executable checksum, and `ffmpeg -version` output when
  available.

## Audio Normalization

The default mode is:

```bash
speech-to-md recording.m4a -o recording-audio-bundle --audio-normalization auto
```

`auto` passes common `whisper.cpp`-readable formats (`.wav`, `.mp3`, `.flac`)
directly and normalizes other local containers to mono 16 kHz WAV with
`ffmpeg`. This is the expected path for M4A/AAC/MP4 audio.

The normalized WAV is an internal temporary file. It is not kept in the final
bundle. The manifest records normalization parameters and checksum metadata
instead of a durable path to the deleted temporary file.

Use a custom `ffmpeg` binary with:

```bash
export SPEECH_TO_MD_FFMPEG_BIN="/absolute/path/to/ffmpeg"
```

or:

```bash
speech-to-md recording.m4a -o recording-audio-bundle --ffmpeg-bin /absolute/path/to/ffmpeg
```

Use `--audio-normalization always` when you want every input to pass through a
consistent WAV normalization path. Use `--audio-normalization never` only for
formats that `whisper.cpp` can read directly.

If the local Metal/GPU path fails, use CPU fallback:

```bash
speech-to-md recording.wav -o recording-audio-bundle --model /absolute/path/to/ggml-model.bin --no-gpu
```

The equivalent environment flag is:

```bash
export SPEECH_TO_MD_WHISPER_CPP_NO_GPU=1
```

## Import Existing Transcript

When ASR has already been run by another trusted tool, package the transcript:

```bash
speech-to-md --transcript transcript.txt --source-audio recording.mp3 -o recording-audio-bundle
```

This path creates a useful LLM bundle without claiming the skill performed ASR.

## Advanced Modes

These are intentionally not part of the first public runtime:

- cloud transcription;
- speaker diarization;
- speaker identity;
- translation;
- meeting-minutes generation;
- hosted ingestion;
- remote URL fetching.

Add each as an explicit workflow with its own doctor checks, privacy warning,
release gate, and output evidence. Cloud transcription must not become a
default local-core engine; it changes the privacy and credential boundary.

## Doctor Status

`speech-to-md --doctor` reports:

- `ok` when `whisper-cli` and a configured model are available;
- `warn` when transcript-import mode can work but local ASR is not ready;
- `fail` for invalid local configuration.

Use `--json` for machine-readable output.
