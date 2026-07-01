Local-only all-MiniLM-L6-v2 ONNX embedding assets live in this folder during
development.

The staged `model.onnx` file is expected to be a dynamic-int8 quantized
feature-extraction export of `sentence-transformers/all-MiniLM-L6-v2` for local
Android testing. The app mean-pools the model's `last_hidden_state` output over
the attention mask and L2-normalizes the result into a 384-dim sentence
embedding.

Expected files after running `scripts/export_minilm_l6_v2.ps1`:
- `model.onnx`
- `tokenizer.json`
- `config.json`
- `tokenizer_config.json`
- `special_tokens_map.json`
- `vocab.txt`

These generated binaries are intentionally git-ignored.
