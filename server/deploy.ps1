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
#   4. publie le serveur (worker.js) et récupère son adresse ;
#   5. écrit cette adresse dans ..\reglages\reseau.txt : il ne reste qu'à réexporter le jeu.
# Le relancer plus tard republie seulement le serveur (la base existante est gardée).

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$wrangler = @('--yes', 'wrangler@4')

function Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Run([string[]]$cmdArgs) {
    $out = & npx @wrangler @cmdArgs 2>&1 | Out-String
    Write-Host $out
    if ($LASTEXITCODE -ne 0) { throw "wrangler $($cmdArgs -join ' ') a échoué (code $LASTEXITCODE)." }
    return $out
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "Node.js n'est pas installé (https://nodejs.org) : il fournit npx, qui lance wrangler."
}

Step "1/5 Connexion à Cloudflare (une page s'ouvre : accepte)"
& npx @wrangler whoami 2>&1 | Out-String | Tee-Object -Variable who | Out-Null
if ($who -match 'not authenticated|You are not') { Run @('login') | Out-Null } else { Write-Host 'Déjà connecté.' }

$toml = Get-Content -Raw -Encoding UTF8 'wrangler.toml'
Step "2/5 La base de données"
if ($toml -match 'database_id = "TO FILL IN"') {
    $out = Run @('d1', 'create', 'jungle-loop')
    $m = [regex]::Match($out, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
    if (-not $m.Success) { throw "Identifiant de la base introuvable dans la réponse de wrangler (ci-dessus)." }
    $toml = $toml -replace 'database_id = "TO FILL IN"', ('database_id = "' + $m.Value + '"')
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'wrangler.toml'), $toml, (New-Object Text.UTF8Encoding $false))
    Write-Host "Base créée : $($m.Value) (notée dans wrangler.toml)"
    Step "3/5 Les tables"
    Run @('d1', 'execute', 'jungle-loop', '--remote', '--file=schema.sql') | Out-Null
} else {
    Write-Host 'La base existe déjà (wrangler.toml a son identifiant) : rien à créer.'
    Step "3/5 Les tables (déjà faites)"
}

Step "4/5 Publication du serveur"
$out = Run @('deploy')
$url = [regex]::Match($out, 'https://[a-z0-9.-]+\.workers\.dev').Value
if (-not $url) { throw "Adresse du serveur introuvable dans la réponse de wrangler (ci-dessus)." }
Write-Host "Serveur en ligne : $url"

Step "5/5 L'adresse dans le jeu (reglages\reseau.txt)"
$cfg = Join-Path $PSScriptRoot '..\reglages\reseau.txt'
$text = Get-Content -Raw -Encoding UTF8 $cfg
$text = [regex]::Replace($text, '(?m)^adresse\s*\|[^#\r\n]*', ('adresse | ' + $url + '   '))
[IO.File]::WriteAllText((Resolve-Path $cfg), $text, (New-Object Text.UTF8Encoding $false))
try {
    $r = Invoke-WebRequest -Method Options -Uri "$url/api/friends" -UseBasicParsing -Headers @{ Origin = 'https://burnout293.github.io' }
    Write-Host "Le serveur répond ($($r.StatusCode))."
} catch { Write-Host "Le serveur ne répond pas encore (il lui faut parfois une minute)." -ForegroundColor Yellow }
Write-Host ''
Write-Host "Fini. Il reste à réexporter le jeu et à le publier : dis-le moi (« réexporte »)." -ForegroundColor Green
