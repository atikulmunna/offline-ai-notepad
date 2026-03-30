Local-only FLAN-T5 Small ONNX assets live in this folder during development.

The staged `model.onnx` and `encoder_model.onnx` files are expected to be
dynamic-int8 quantized exports for local Android testing.

Expected files after running `scripts/export_flan_t5_small.ps1`:
- `model.onnx`
- `encoder_model.onnx`
- `tokenizer.json`
- `config.json`
- `tokenizer_config.json`
- `generation_config.json`
- `special_tokens_map.json`
- `spiece.model`

These generated binaries are intentionally git-ignored.
