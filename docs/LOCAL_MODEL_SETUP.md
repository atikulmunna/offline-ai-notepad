# Local Model Setup

This project keeps large model binaries out of normal Git history.

For local development, the summarization model (Falconsai/text_summarization, a
T5-small fine-tuned for summarization) can be exported to ONNX and staged into
the Flutter asset directory with:

```powershell
.\scripts\export_falconsai.ps1
```

What the script does:

1. Creates a local export output under `local_models/falconsai_sum/onnx`
2. Exports `Falconsai/text_summarization` to ONNX via the optimum python module
3. Quantizes the decoder and encoder ONNX weights to dynamic int8
4. Copies the quantized decoder export to `assets/models/falconsai-summarizer-en-v1/model.onnx`
5. Copies the quantized `encoder_model.onnx` beside it
6. Copies tokenizer/config files needed for local runtime inspection

The semantic-search embedding model is staged separately with
`.\scripts\export_minilm_l6_v2.ps1`.

Notes:

- The exported model files under `local_models/` and `assets/models/falconsai-summarizer-en-v1/` are git-ignored.
- The repo expects the summarizer decoder asset at `assets/models/falconsai-summarizer-en-v1/model.onnx` and the paired encoder at `assets/models/falconsai-summarizer-en-v1/encoder_model.onnx`.
- The local test path uses quantized ONNX files because the float32 exports are too heavy to bundle. Unlike a general instruction model, this summarization-fine-tuned model stays on-topic even at int8.
- After staging assets, run `flutter pub get` and rebuild the app so Flutter bundles the local model assets.
