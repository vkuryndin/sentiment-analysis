param([switch]$RecordModelHashes)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Download-File([string]$Url, [string]$Path, [string]$Sha256 = '') {
    if (Test-Path -LiteralPath $Path) {
        if ((Get-Item -LiteralPath $Path).Length -eq 0) {
            throw "Empty file: $Path. Delete it and run prepare.ps1 again."
        }
        if ($Sha256 -and (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Sha256) {
            throw "Invalid checksum: $Path. Delete it and run prepare.ps1 again."
        }
        Write-Host "Already present: $Path"
        return
    }
    $temp = "$Path.download"
    try {
        Write-Host "Downloading $Path"
        Invoke-WebRequest -Uri $Url -OutFile $temp -UseBasicParsing
        if ((Get-Item -LiteralPath $temp).Length -eq 0) {
            throw "Downloaded file is empty: $Path"
        }
        if ($Sha256 -and (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash -ne $Sha256) {
            throw "Invalid checksum: $Path"
        }
        Move-Item -LiteralPath $temp -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}

$models = [ordered]@{
    'models/yelp_review_polarity.ftz' = @{ Url = 'https://dl.fbaipublicfiles.com/fasttext/supervised-models/yelp_review_polarity.ftz'; Size = 1547836 }
    'models/rubert/model.onnx' = @{ Url = 'https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main/onnx/model_quantized.onnx'; Size = 11965912 }
    'models/rubert/tokenizer.json' = @{ Url = 'https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main/tokenizer.json'; Size = 705727 }
    'models/rubert/config.json' = @{ Url = 'https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main/config.json'; Size = 968 }
}

# Explicit one-time operation, only on the locally tested model files.
if ($RecordModelHashes) {
    if (Test-Path -LiteralPath 'models.sha256') {
        throw 'models.sha256 already exists; do not overwrite verified hashes automatically.'
    }
    $lines = foreach ($path in $models.Keys) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $models[$path].Size) {
            throw "Missing file or unexpected size: $path"
        }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $path"
    }
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'models.sha256'), (($lines -join "`n") + "`n"), [System.Text.Encoding]::ASCII)
    Write-Host 'Created models.sha256 from the local model files.'
    return
}

if (!(Test-Path -LiteralPath 'models.sha256' -PathType Leaf)) {
    throw 'Missing models.sha256. Obtain the committed checksum manifest before downloading models.'
}
$hashes = @{}
foreach ($line in Get-Content -LiteralPath 'models.sha256') {
    if ($line -cnotmatch '^([0-9a-f]{64})  (models/[^ ]+)$') { throw "Invalid checksum line: $line" }
    $hash = $Matches[1]
    $path = $Matches[2]
    if (!$models.Contains($path) -or $hashes.ContainsKey($path)) { throw "Unexpected checksum path: $path" }
    $hashes[$path] = $hash
}
if ($hashes.Count -ne $models.Count) { throw 'Incomplete model checksum manifest.' }

New-Item -ItemType Directory -Force -Path 'gradle/wrapper', 'models', 'models/rubert' | Out-Null
$base = 'https://raw.githubusercontent.com/gradle/gradle/v8.14.3'
Download-File "$base/gradlew" 'gradlew'
Download-File "$base/gradlew.bat" 'gradlew.bat'
Download-File "$base/gradle/wrapper/gradle-wrapper.jar" 'gradle/wrapper/gradle-wrapper.jar' '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172'
foreach ($path in $models.Keys) {
    Download-File ($models[$path].Url) $path ($hashes[$path])
}
Get-ChildItem models, models/rubert -File | Select-Object Name, Length
