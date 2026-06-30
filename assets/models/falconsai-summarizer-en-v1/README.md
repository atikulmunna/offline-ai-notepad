Local-only Falconsai/text_summarization ONNX assets live in this folder during
development. It is a T5-small model fine-tuned for summarization, so it shares
the same architecture and SentencePiece tokenizer as the prior FLAN-T5 slot but
produces on-topic summaries and tolerates INT8 quantization.

The staged `model.onnx` (decoder) and `encoder_model.onnx` are dynamic-int8
quantized exports for local Android testing (~88 MB combined).

Expected files after running `scripts/export_falconsai.ps1`:
- `model.onnx`
- `encoder_model.onnx`
- `tokenizer.json`
- `config.json`
- `tokenizer_config.json`
- `generation_config.json`
- `special_tokens_map.json`
- `spiece.model`

These generated binaries are intentionally git-ignored.
