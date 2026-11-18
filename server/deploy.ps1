# Met le serveur de Jungle Loop en ligne sur ton compte Cloudflare (gratuit), en une fois.
#
# Avant : crée ton compte sur https://dash.cloudflare.com (e-mail + mot de passe, rien à payer).
# Puis, dans ce dossier (Jungle-Loop-Godot\server) :
#     powershell -ExecutionPolicy Bypass -File deploy.ps1
#
# Ce que fait le script, dans l'ordre (il s'arrête à la première erreur) :
#   1. ouvre la page Cloudflare pour autoriser l'outil « wrangler » (une fois) ;
#   2. crée la base de données « jungle-loop » et note son identifiant dans wrangler.toml ;
#   3. y crée les tables (schema.sql) ;
#   4. publie le serveur (worker.js) et récupère son adresse. La première fois, Cloudflare demande de
#      choisir ton sous-domaine workers.dev (le nom qui sera dans l'adresse) : wrangler te pose la question ;
#   5. écrit cette adresse dans ..\reglages\reseau.txt : il ne reste qu'à réexporter le jeu.
# Le relancer plus tard republie seulement le serveur (la base existante est gardée).

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$wrangler = @('--yes', 'wrangler@4')
$oldEncoding = [Console]::OutputEncoding
$script:wranglerCode = 0

function Write-Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Write-Tip($text) { Write-Host $text -ForegroundColor Yellow }

# Lance wrangler en gardant ce qu'il écrit. Ses avertissements arrivent sur stderr : ce ne sont pas des
# erreurs (PowerShell 5.1 en ferait une erreur fatale avec 2>&1), seul son code de sortie compte.
function Invoke-Wrangler([string[]]$cmdArgs, [switch]$MayFail) {
    $ErrorActionPreference = 'Continue'
    $out = (& npx @wrangler @cmdArgs 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $script:wranglerCode = $LASTEXITCODE
    Write-Host $out
    if ($script:wranglerCode -ne 0 -and -not $MayFail) {
        throw "wrangler $($cmdArgs -join ' ') a échoué (code $($script:wranglerCode))."
    }
    return $out
}

try {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false   # wrangler écrit en UTF-8

    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw "Node.js n'est pas installé (https://nodejs.org) : il fournit npx, qui lance wrangler."
    }

    Write-Step "1/5 Connexion à Cloudflare"
    $who = Invoke-Wrangler @('whoami') -MayFail
    if ($script:wranglerCode -ne 0 -or $who -match 'not authenticated|You are not') {
        Write-Tip "Une page Cloudflare s'ouvre dans ton navigateur : clique « Allow » (autoriser), puis reviens ici."
        & npx @wrangler login
        if ($LASTEXITCODE -ne 0) { throw "La connexion à Cloudflare a échoué (code $LASTEXITCODE)." }
    } else { Write-Host 'Déjà connecté.' }

    $toml = Get-Content -Raw -Encoding UTF8 'wrangler.toml'
    Write-Step "2/5 La base de données"
    if ($toml -match 'database_id = "TO FILL IN"') {
        $out = Invoke-Wrangler @('d1', 'create', 'jungle-loop')
        $m = [regex]::Match($out, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
        if (-not $m.Success) { throw "Identifiant de la base introuvable dans la réponse de wrangler (ci-dessus)." }
        $toml = $toml -replace 'database_id = "TO FILL IN"', ('database_id = "' + $m.Value + '"')
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'wrangler.toml'), $toml, (New-Object Text.UTF8Encoding $false))
        Write-Host "Base créée : $($m.Value) (notée dans wrangler.toml)"
        Write-Step "3/5 Les tables"
        Invoke-Wrangler @('d1', 'execute', 'jungle-loop', '--remote', '--file=schema.sql') | Out-Null
    } else {
        Write-Host 'La base existe déjà (wrangler.toml a son identifiant) : rien à créer.'
        Write-Step "3/5 Les tables (déjà faites)"
    }

    Write-Step "4/5 Publication du serveur"
    $out = Invoke-Wrangler @('deploy') -MayFail
    if ($out -match 'register a workers\.dev subdomain') {
        # Compte tout neuf : il lui faut un sous-domaine workers.dev. wrangler ne le demande que s'il
        # peut te parler directement : on le relance donc dans la fenêtre, sans garder sa réponse.
        Write-Host ''
        Write-Tip "Ton compte n'a pas encore de sous-domaine workers.dev : c'est le nom qui sera dans l'adresse"
        Write-Tip "du serveur (https://jungle-loop.TON-NOM.workers.dev). wrangler va te poser ses questions en anglais :"
        Write-Tip "  - « Would you like to register a workers.dev subdomain now? » : tape y puis Entrée ;"
        Write-Tip "  - « What would you like your workers.dev subdomain to be? » : tape un nom (lettres minuscules,"
        Write-Tip "    chiffres, tirets), puis Entrée. S'il est déjà pris, il en redemande un ;"
        Write-Tip "  - s'il demande encore une confirmation (« Ok to proceed? ») : y puis Entrée."
        Write-Host ''
        & npx @wrangler deploy
        if ($LASTEXITCODE -ne 0) {
            throw ("La publication a échoué (code $LASTEXITCODE). Autre moyen : choisis ton sous-domaine sur " +
                   "https://dash.cloudflare.com (menu Workers & Pages), puis relance ce script.")
        }
        Write-Host ''
        Write-Host "Sous-domaine choisi. Nouvelle publication (rien ne change) pour lire l'adresse :"
        $out = Invoke-Wrangler @('deploy')
    } elseif ($script:wranglerCode -ne 0) {
        throw "La publication a échoué (code $($script:wranglerCode)) : voir le message de wrangler ci-dessus."
    }
    $url = [regex]::Match($out, 'https://[a-z0-9.-]+\.workers\.dev').Value
    if (-not $url) { throw "Adresse du serveur introuvable dans la réponse de wrangler (ci-dessus)." }
    Write-Host "Serveur en ligne : $url"

    Write-Step "5/5 L'adresse dans le jeu (reglages\reseau.txt)"
    $cfg = Join-Path $PSScriptRoot '..\reglages\reseau.txt'
    $text = Get-Content -Raw -Encoding UTF8 $cfg
    $text = [regex]::Replace($text, '(?m)^adresse\s*\|[^#\r\n]*', ('adresse | ' + $url + '   '))
    [IO.File]::WriteAllText((Resolve-Path $cfg), $text, (New-Object Text.UTF8Encoding $false))
    try {
        $r = Invoke-WebRequest -Method Options -Uri "$url/api/friends" -UseBasicParsing -Headers @{ Origin = 'https://burnout293.github.io' }
        Write-Host "Le serveur répond ($($r.StatusCode))."
    } catch { Write-Tip "Le serveur ne répond pas encore (un sous-domaine neuf met parfois quelques minutes) : ce n'est pas grave." }
    Write-Host ''
    Write-Host "Fini. Il reste à réexporter le jeu et à le publier : dis-le moi (« réexporte »)." -ForegroundColor Green
} finally {
    [Console]::OutputEncoding = $oldEncoding
}
