# Branche le relais (TURN) de Cloudflare sur le serveur de Jungle Loop : il fait passer une partie à deux
# quand les deux appareils ne peuvent pas se parler directement (en 4G / 5G, c'est souvent bloqué).
# Gratuit jusqu'à 1 000 Go par mois (une course à deux en utilise très peu).
#
# Avant, une fois : crée une clé de relais sur https://dash.cloudflare.com/?to=/:account/calls
# (menu « Realtime », parfois appelé « Calls » → « TURN Server » → « Create », nom : jungle-loop).
# Cloudflare montre alors deux valeurs : le « Turn Token ID » et l'« API Token ». Garde la page ouverte.
# Puis, dans ce dossier (Jungle-Loop-Godot\server) :
#     powershell -ExecutionPolicy Bypass -File turn.ps1
#
# Le script te demande les deux valeurs (colle-les avec un clic droit), vérifie auprès de Cloudflare qu'elles
# marchent, puis les range comme secrets du serveur. Elles ne sont écrites nulle part ailleurs : ni dans les
# fichiers du jeu, ni dans ceux du dépôt. Le relancer remplace les anciennes.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$wrangler = @('--yes', 'wrangler@4')

function Write-Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "Node.js n'est pas installé (https://nodejs.org) : il fournit npx, qui lance wrangler."
}

Write-Step "1/3 Les deux valeurs de ta clé de relais"
$id = (Read-Host "Turn Token ID").Trim()
$secure = Read-Host "API Token (il ne s'affiche pas quand tu le colles, c'est normal)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim() }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
if (-not $id -or -not $token) { throw "Il manque une des deux valeurs : relance le script." }

Write-Step "2/3 Essai auprès de Cloudflare"
try {
    $r = Invoke-RestMethod -Method Post -Uri "https://rtc.live.cloudflare.com/v1/turn/keys/$id/credentials/generate-ice-servers" `
        -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body '{"ttl":60}'
} catch {
    throw "Cloudflare refuse cette clé ($($_.Exception.Message)). Vérifie les deux valeurs (pas d'espace en trop), puis relance."
}
if (-not $r.iceServers) { throw "Cloudflare a répondu sans relais : vérifie les deux valeurs, puis relance." }
Write-Host "La clé marche."

Write-Step "3/3 Rangement dans les secrets du serveur"
# Chaque valeur passe à wrangler par son entrée, telle quelle : sans marque d'encodage (BOM) devant, que
# PowerShell 5.1 ajoute quand la console est en UTF-8 (le serveur l'enlèverait de toute façon).
$OutputEncoding = New-Object Text.UTF8Encoding $false
$oldInput = [Console]::InputEncoding
try {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    foreach ($pair in @(@('TURN_KEY_ID', $id), @('TURN_KEY_TOKEN', $token))) {
        $pair[1] | & npx @wrangler secret put $pair[0]
        if ($LASTEXITCODE -ne 0) { throw "wrangler n'a pas pu ranger $($pair[0]) (code $LASTEXITCODE) : voir son message ci-dessus." }
    }
} finally {
    [Console]::InputEncoding = $oldInput
}
$token = $null
Write-Host ''
Write-Host "Fini : le serveur donne maintenant le relais aux parties à deux. Rien à réexporter, essaie directement." -ForegroundColor Green
