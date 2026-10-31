$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoots = @('lib', 'test', 'integration_test', 'test_driver', 'web_app/lib')
$files = foreach ($relativeRoot in $sourceRoots) {
    $path = Join-Path $repoRoot $relativeRoot
    if (Test-Path -LiteralPath $path) {
        Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.dart'
    }
}

$markers = $files | Select-String -Pattern '(?://|/\*)\s*(TODO|FIXME|HACK|XXX)\b'
if ($markers) {
    Write-Host 'Technical-debt markers found:'
    $markers | ForEach-Object {
        $relativePath = $_.Path.Substring($repoRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
        Write-Host ("{0}:{1}: {2}" -f $relativePath, $_.LineNumber, $_.Line.Trim())
    }
} else {
    Write-Host 'No technical-debt markers found.'
}
