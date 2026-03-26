# Local Model Setup

This project keeps large model binaries out of normal Git history.

For local development, FLAN-T5 Small can be exported to ONNX and staged into the Flutter asset directory with:

```powershell
.\scripts\export_flan_t5_small.ps1
```

What the script does:

1. Creates a local export output under `local_models/flan_t5_small/onnx`
2. Exports `google/flan-t5-small` to ONNX with `optimum-cli`
3. Copies the merged decoder export to `assets/models/flan-t5-small-summarizer-en-v1/model.onnx`
4. Copies tokenizer/config files needed for local runtime inspection

Notes:

- The exported model files under `local_models/` and `assets/models/flan-t5-small-summarizer-en-v1/` are git-ignored.
- The repo currently expects the summarizer asset at `assets/models/flan-t5-small-summarizer-en-v1/model.onnx`.
- After staging assets, run `flutter pub get` and rebuild the app so Flutter bundles the local model assets.
