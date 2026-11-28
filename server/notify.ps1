# Te prévient dès qu'un joueur envoie un retour depuis la page « Ton avis » du site (retours.html).
# Deux façons, au choix (les deux peuvent marcher ensemble : relance le script pour la seconde) :
#
#   1. Par e-mail, avec Resend (gratuit jusqu'à 3 000 e-mails par mois) :
#      crée un compte sur https://resend.com avec l'adresse où tu veux recevoir les retours, puis
#      « API Keys » → « Create API Key » (droit « Sending access »). Garde la clé affichée.
#      Sans domaine à toi, Resend n'envoie qu'à l'adresse de ton compte : c'est justement ce qu'il faut.
#
#   2. En notification sur ton téléphone, avec ntfy (gratuit, sans compte) :
#      installe l'appli « ntfy » (Android ou iPhone), puis abonne-toi au sujet que ce script te donne.
#      Garde ce sujet pour toi : quiconque le connaît peut lire les retours.
#
# Puis, dans ce dossier (Jungle-Loop\server) :
#     powershell -ExecutionPolicy Bypass -File notify.ps1
#
# Les valeurs sont rangées comme secrets du serveur, nulle part ailleurs (ni dans le jeu, ni dans le dépôt).
# Sans elles, les retours sont quand même gardés dans la base (voir le README de ce dossier pour les lire).

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$wrangler = @('--yes', 'wrangler@4')

function Write-Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }

function Put-Secrets($pairs) {
    # Chaque valeur passe à wrangler par son entrée, sans marque d'encodage (BOM) devant (PowerShell 5.1).
    $OutputEncoding = New-Object Text.UTF8Encoding $false
    $oldInput = [Console]::InputEncoding
    try {
        [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
        foreach ($pair in $pairs) {
            $pair[1] | & npx @wrangler secret put $pair[0]
            if ($LASTEXITCODE -ne 0) { throw "wrangler n'a pas pu ranger $($pair[0]) (code $LASTEXITCODE) : voir son message ci-dessus." }
        }
    } finally {
        [Console]::InputEncoding = $oldInput
    }
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "Node.js n'est pas installé (https://nodejs.org) : il fournit npx, qui lance wrangler."
}

Write-Step "Comment veux-tu être prévenu ?"
Write-Host "  1 = par e-mail (Resend)"
Write-Host "  2 = en notification sur le téléphone (ntfy)"
$choice = (Read-Host "Ton choix (1 ou 2)").Trim()

if ($choice -eq '1') {
    Write-Step "1/3 Ta clé Resend et ton adresse"
    $secure = Read-Host "Clé API Resend (elle ne s'affiche pas quand tu la colles, c'est normal)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim() }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $mail = (Read-Host "L'adresse de ton compte Resend (où arriveront les retours)").Trim()
    if (-not $key -or -not $mail) { throw "Il manque la clé ou l'adresse : relance le script." }

    Write-Step "2/3 Un e-mail d'essai"
    $body = @{ from = 'Jungle Loop <onboarding@resend.dev>'; to = @($mail); subject = 'Jungle Loop : essai des retours';
        text = "Si tu lis ceci, les retours de la page « Ton avis » t'arriveront ici." } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method Post -Uri 'https://api.resend.com/emails' -Headers @{ Authorization = "Bearer $key" } `
            -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
    } catch {
        throw "Resend refuse l'envoi ($($_.Exception.Message)). Vérifie la clé, et que l'adresse est bien celle du compte Resend."
    }
    Write-Host "E-mail d'essai envoyé : regarde ta boîte (et les indésirables)."

    Write-Step "3/3 Rangement dans les secrets du serveur"
    Put-Secrets @(@('RESEND_KEY', $key), @('NOTIFY_EMAIL', $mail))
    $key = $null
    Write-Host ''
    Write-Host "Fini : chaque retour t'arrive maintenant par e-mail." -ForegroundColor Green
}
elseif ($choice -eq '2') {
    Write-Step "1/3 Ton sujet ntfy"
    $chars = 'abcdefghijkmnpqrstuvwxyz23456789'
    $topic = 'jungle-loop-' + (-join (1..14 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] }))
    Write-Host "Dans l'appli ntfy : « + » (s'abonner), serveur par défaut (ntfy.sh), sujet :"
    Write-Host "    $topic" -ForegroundColor Yellow
    Read-Host "Abonne-toi, puis appuie sur Entrée" | Out-Null

    Write-Step "2/3 Une notification d'essai"
    try {
        Invoke-RestMethod -Method Post -Uri "https://ntfy.sh/$topic" -Headers @{ Title = 'Jungle Loop' } `
            -Body ([Text.Encoding]::UTF8.GetBytes("Essai : les retours de la page « Ton avis » arriveront ici.")) | Out-Null
    } catch {
        throw "ntfy n'a pas répondu ($($_.Exception.Message)) : réessaie plus tard."
    }
    Write-Host "Notification d'essai envoyée : regarde ton téléphone."

    Write-Step "3/3 Rangement dans les secrets du serveur"
    Put-Secrets @(, @('NTFY_TOPIC', $topic))
    Write-Host ''
    Write-Host "Fini : chaque retour t'arrive maintenant en notification." -ForegroundColor Green
}
else {
    throw "Réponds 1 ou 2 : relance le script."
}
