$urls = @(
    "https://dl.google.com/dl/android/maven2/com/android/tools/build/builder/8.12.1/builder-8.12.1.jar"
    "https://dl.google.com/dl/android/maven2/com/android/tools/build/builder/8.12.1/builder-8.12.1.pom"
    "https://dl.google.com/dl/android/maven2/com/android/tools/analytics-library/protos/31.12.1/protos-31.12.1.jar"
    "https://dl.google.com/dl/android/maven2/com/android/tools/analytics-library/protos/31.12.1/protos-31.12.1.pom"
    "https://dl.google.com/dl/android/maven2/com/android/tools/build/apksig/8.12.1/apksig-8.12.1.jar"
    "https://dl.google.com/dl/android/maven2/com/android/tools/build/apksig/8.12.1/apksig-8.12.1.pom"
)

$baseDir = "$env:USERPROFILE\.m2\repository"

foreach ($url in $urls) {
    $uri = [System.Uri]$url
    # Extract the Maven path portion (e.g. /com/android/...)
    $mavenPath = $uri.AbsolutePath.Replace('/dl/android/maven2/', '')
    $mavenPath = $mavenPath.Replace('/', '\')
    $destPath = Join-Path -Path $baseDir -ChildPath $mavenPath
    
    $dir = [System.IO.Path]::GetDirectoryName($destPath)
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    
    Write-Host "Downloading $url to $destPath"
    try {
        Invoke-WebRequest -Uri $url -OutFile $destPath -ErrorAction Stop
        Write-Host "Success." -ForegroundColor Green
    } catch {
        Write-Host "Failed to download $url" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}
