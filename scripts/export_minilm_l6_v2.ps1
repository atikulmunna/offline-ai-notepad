param(
    [string]$PythonExe = ".\.venv-model-export\Scripts\python.exe",
    [string]$OptimumCli = ".\.venv-model-export\Scripts\optimum-cli.exe",
    [string]$ModelId = "sentence-transformers/all-MiniLM-L6-v2",
    [string]$ExportDir = "local_models\all_minilm_l6_v2\onnx",
    [string]$AssetDir = "assets\models\embedding-minilm-l6-v2-en-v1"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at '$PythonExe'. Create the local export venv first."
}

if (-not (Test-Path $OptimumCli)) {
    throw "optimum-cli not found at '$OptimumCli'. Install the export toolchain in the local venv first."
}

New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null
New-Item -ItemType Directory -Force -Path $AssetDir | Out-Null

# all-MiniLM-L6-v2 is a BERT encoder. The feature-extraction task exports a
# single encoder graph whose `last_hidden_state` output we mean-pool + L2
# normalize on-device to produce 384-dim sentence embeddings.
& $OptimumCli export onnx `
    -m $ModelId `
    --task feature-extraction `
    $ExportDir

$quantizeScript = @'
from pathlib import Path
from onnxruntime.quantization import QuantType, quantize_dynamic

base = Path(r"{EXPORT_DIR}")
targets = [
    ("model.onnx", "model.int8.onnx"),
]

for source_name, target_name in targets:
    source = base / source_name
    target = base / target_name
    quantize_dynamic(
        model_input=str(source),
        model_output=str(target),
        weight_type=QuantType.QInt8,
        per_channel=False,
        reduce_range=True,
    )
    print(f"quantized {source_name} -> {target_name}")
'@.Replace("{EXPORT_DIR}", (Resolve-Path $ExportDir).Path)

& $PythonExe -c $quantizeScript

$copyMap = @{
    "model.int8.onnx" = "model.onnx"
    "tokenizer.json" = "tokenizer.json"
    "config.json" = "config.json"
    "tokenizer_config.json" = "tokenizer_config.json"
    "special_tokens_map.json" = "special_tokens_map.json"
    "vocab.txt" = "vocab.txt"
}

foreach ($entry in $copyMap.GetEnumerator()) {
    $source = Join-Path $ExportDir $entry.Key
    if (-not (Test-Path $source)) {
        throw "Expected export file missing: $source"
    }

    $target = Join-Path $AssetDir $entry.Value
    Copy-Item -LiteralPath $source -Destination $target -Force
}

Write-Host "all-MiniLM-L6-v2 ONNX embedding assets exported to '$ExportDir' and staged to '$AssetDir'."
