param(
    [string]$PythonExe = ".\.venv-model-export\Scripts\python.exe",
    [string]$OptimumCli = ".\.venv-model-export\Scripts\optimum-cli.exe",
    [string]$ModelId = "google/flan-t5-small",
    [string]$ExportDir = "local_models\flan_t5_small\onnx",
    [string]$AssetDir = "assets\models\flan-t5-small-summarizer-en-v1"
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

& $OptimumCli export onnx `
    -m $ModelId `
    --task text2text-generation-with-past `
    $ExportDir

$copyMap = @{
    "decoder_model_merged.onnx" = "model.onnx"
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

    $target = Join-Path $AssetDir $entry.Value
    Copy-Item -LiteralPath $source -Destination $target -Force
}

Write-Host "FLAN-T5 Small ONNX assets exported to '$ExportDir' and staged to '$AssetDir'."
