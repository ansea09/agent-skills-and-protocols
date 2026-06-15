# Audio Transcript Bundle

This reference defines the output contract for `speech-to-md`.

## Purpose

The bundle is for LLM analysis of a speech recording. It separates the clean
transcript from evidence and audit material so an agent can answer ordinary
content questions from `content.md`, and inspect timestamps, source metadata,
and warnings when quoteability or trust matters.

## Files

| File | Purpose |
| --- | --- |
| `LLM_README.md` | Entry point for Codex, Claude Code, and other agents. |
| `content.md` | Clean transcript text with minimal timestamp noise. |
| `segments.md` | Timestamped segment view for evidence-sensitive reading. |
| `segments.json` | Machine-readable segment records. |
| `manifest.json` | Source checksum, size, engine, runtime fingerprint, model, command, audio normalization, and generated file list. |
| `audit.md` | Warnings, unsupported features, and trust boundaries. |
| `conversion-report.md` | Short human-readable run report. |
| `timestamps.vtt` | Optional timed text emitted by the ASR engine. |

## Agent Reading Order

1. Read `LLM_README.md`.
2. Read `content.md` for the main transcript.
3. Inspect `audit.md` before making claims about transcript quality, speaker
   labels, exact quotes, missing audio, language, or unsupported features.
4. Use `segments.md` or `segments.json` for timestamped evidence.
5. Do not infer speaker identity, diarization, or confidence if those fields
   are absent.

## Segment Record

`segments.json` contains:

```json
{
  "schema": "speech-to-md.segments.v1",
  "segments": [
    {
      "index": 1,
      "start": 0.0,
      "end": 4.2,
      "start_label": "00:00:00.000",
      "end_label": "00:00:04.200",
      "speaker": null,
      "text": "Example transcript segment."
    }
  ]
}
```

Fields may be `null` when the selected engine did not provide them.

## Quality Interpretation

The transcript is ASR output. It is not authoritative evidence of what was said
unless a stronger review process has checked the audio. The bundle must keep
engine, model, command, runtime fingerprint, warnings, and unsupported features
visible.

When audio is normalized before ASR, temporary normalized WAV files are not
retained. `manifest.json` records that normalization happened, the target
format, sample rate, channels, normalized stream checksum, and the `ffmpeg`
fingerprint, but it must not point agents at a deleted temporary path as if it
were durable evidence.

The first local workflow does not provide diarization, speaker identity,
speaker attribution, translation, or confidence calibration.
