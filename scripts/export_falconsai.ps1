param(
    [string]$PythonExe = ".\.venv-model-export\Scripts\python.exe",
    [string]$ModelId = "Falconsai/text_summarization",
    [string]$ExportDir = "local_models\falconsai_sum\onnx",
    [string]$AssetDir = "assets\models\falconsai-summarizer-en-v1"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at '$PythonExe'. Create the local export venv first."
}

New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null
New-Item -ItemType Directory -Force -Path $AssetDir | Out-Null

# NOTE: invoke optimum via the python module, not optimum-cli.exe. The .exe
# wrapper exits silently with code 1 on this toolchain (see memory).
& $PythonExe -m optimum.commands.optimum_cli export onnx `
    -m $ModelId `
    --task text2text-generation-with-past `
    $ExportDir

$quantizeScript = @'
from pathlib import Path
from onnxruntime.quantization import QuantType, quantize_dynamic

base = Path(r"{EXPORT_DIR}")
targets = [
    ("decoder_model.onnx", "decoder_model.int8.onnx"),
    ("encoder_model.onnx", "encoder_model.int8.onnx"),
]

for source_name, target_name in targets:
    quantize_dynamic(
        model_input=str(base / source_name),
        model_output=str(base / target_name),
        weight_type=QuantType.QInt8,
        per_channel=False,
        reduce_range=True,
    )
    print(f"quantized {source_name} -> {target_name}")
'@.Replace("{EXPORT_DIR}", (Resolve-Path $ExportDir).Path)

& $PythonExe -c $quantizeScript

$copyMap = @{
    "decoder_model.int8.onnx" = "model.onnx"
    "encoder_model.int8.onnx" = "encoder_model.onnx"
    "tokenizer.json" = "tokenizer.json"
    "config.json" = "config.json"
    "tokenizer_config.json" = "tokenizer_config.json"
    "generation_config.json" = "generation_config.json"
    "special_tokens_map.json" = "special_tokens_map.json"
    "spiece.model" = "spiece.model"
}

foreach ($entry in $copyMap.GetEnumerator()) {
    $source = Join-Path $ExportDir $entry.Key
    if (-not (Test-Path $source)) {
        throw "Expected export file missing: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $AssetDir $entry.Value) -Force
}

Write-Host "Falconsai summarizer ONNX assets exported to '$ExportDir' and staged to '$AssetDir'."
