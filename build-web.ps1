# Build Portal Salaf versi web lalu salin ke Laravel (portal_salaf/public/app).
# Jalankan dari folder ini:  .\build-web.ps1
# Setelah itu deploy Laravel seperti biasa; web bisa dibuka di https://portalsalaf.rupamedia.my.id/app/

# Kegagalan dicek lewat exit code (flutter menulis info biasa ke stderr)
Set-Location $PSScriptRoot

$tujuan = Join-Path $PSScriptRoot '..\portal_salaf\public\app'

flutter build web --release --base-href /app/ --dart-define-from-file=firebase-config.json
if ($LASTEXITCODE -ne 0) { throw 'Build web gagal.' }

# /MIR: isi folder tujuan disamakan persis dengan hasil build (file lama ikut terhapus)
robocopy build\web $tujuan /MIR /NFL /NDL /NJH /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Gagal menyalin ke $tujuan" }

Write-Host "Selesai: hasil build ada di $((Resolve-Path $tujuan).Path)"
exit 0
