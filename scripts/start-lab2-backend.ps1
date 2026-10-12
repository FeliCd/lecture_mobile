param([switch]$Test, [switch]$NoSeed, [switch]$SkipInstall)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path -LiteralPath 'functions/.secret.local')) {
    Set-Content -LiteralPath 'functions/.secret.local' -Encoding utf8 -Value "QR_SIGNING_SECRET=emulator-only-signing-key`nOPENALEX_API_KEY=emulator-public-access"
}
Push-Location functions
try {
    if (-not $SkipInstall) {
        & npm ci
        if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
    }
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw 'TypeScript build failed' }
} finally { Pop-Location }
$env:FUNCTIONS_DISCOVERY_TIMEOUT='60'
if ($Test) {
    & firebase emulators:exec --project demo-fap-lab2 --only 'auth,firestore,functions' 'node scripts/seed.cjs && cd functions && node --test test/emulator.cjs'
} elseif ($NoSeed) {
    & firebase emulators:start --project demo-fap-lab2 --only 'auth,firestore,functions'
} else {
    & firebase emulators:exec --ui --project demo-fap-lab2 --only 'auth,firestore,functions' 'node scripts/seed.cjs && node scripts/keep-emulators-alive.cjs'
}
exit $LASTEXITCODE
