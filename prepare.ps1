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

New-Item -ItemType Directory -Force -Path 'gradle/wrapper', 'models', 'models/rubert' | Out-Null
$base = 'https://raw.githubusercontent.com/gradle/gradle/v8.14.3'
Download-File "$base/gradlew" 'gradlew'
Download-File "$base/gradlew.bat" 'gradlew.bat'
Download-File "$base/gradle/wrapper/gradle-wrapper.jar" 'gradle/wrapper/gradle-wrapper.jar' '7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172'
Download-File 'https://dl.fbaipublicfiles.com/fasttext/supervised-models/yelp_review_polarity.ftz' 'models/yelp_review_polarity.ftz'
$ru = 'https://huggingface.co/onnx-community/rubert-tiny-sentiment-balanced-ONNX/resolve/main'
Download-File "$ru/onnx/model_quantized.onnx" 'models/rubert/model.onnx'
Download-File "$ru/tokenizer.json" 'models/rubert/tokenizer.json'
Download-File "$ru/config.json" 'models/rubert/config.json'
Get-ChildItem models, models/rubert -File | Select-Object Name, Length
