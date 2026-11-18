# Met le serveur de Jungle Loop en ligne sur ton compte Cloudflare (gratuit), en une fois.
#
# Avant : crée ton compte sur https://dash.cloudflare.com (e-mail + mot de passe, rien à payer).
# Puis, dans ce dossier (Jungle-Loop-Godot\server) :
#     powershell -ExecutionPolicy Bypass -File deploy.ps1
#
# Ce que fait le script, dans l'ordre (il s'arrête à la première erreur, et peut être relancé autant de
# fois qu'il faut : il reprend où il en était) :
#   1. ouvre la page Cloudflare pour autoriser l'outil « wrangler » (une fois) ;
#   2. crée la base de données « jungle-loop » et note son identifiant dans wrangler.toml ;
#   3. y crée les tables (schema.sql ; sans rien effacer si elles existent déjà) ;
#   4. publie le serveur (worker.js) et récupère son adresse. La première fois, Cloudflare demande de
#      choisir ton sous-domaine workers.dev (le nom qui sera dans l'adresse) : wrangler te pose la question ;
#   5. écrit cette adresse dans ..\reglages\reseau.txt et vérifie que le serveur et sa base répondent.
# Il ne reste alors qu'à réexporter le jeu.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$wrangler = @('--yes', 'wrangler@4')
$oldEncoding = [Console]::OutputEncoding
$script:wranglerCode = 0
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

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

# Ce que répond le serveur à une question d'un joueur inconnu : 403 = il tourne et sa base a ses tables
# (une table manquante donnerait 500) ; 0 = pas joignable, 404 = adresse pas encore branchée (un serveur ou
# un sous-domaine neufs mettent parfois quelques minutes).
function Get-ServerAnswer([string]$url) {
    try {
        $r = Invoke-WebRequest -Method Post -Uri "$url/api/friends" -Body '{"id":"verification","secret":"-"}' `
            -ContentType 'application/json' -UseBasicParsing -TimeoutSec 20
        return [int]$r.StatusCode
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { return [int]$resp.StatusCode }
        return 0
    }
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
    } else {
        Write-Host 'La base existe déjà (wrangler.toml a son identifiant) : rien à créer.'
    }

    # Toujours refait : schema.sql ne crée que ce qui manque (CREATE ... IF NOT EXISTS), rien n'est effacé.
    # (Un premier lancement interrompu a pu créer la base sans ses tables.)
    Write-Step "3/5 Les tables"
    Invoke-Wrangler @('d1', 'execute', 'jungle-loop', '--remote', '--file=schema.sql', '--yes') | Out-Null

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
        Write-Host ''
        Write-Host "Nouvelle publication (rien ne change) pour lire l'adresse :"
        $out = Invoke-Wrangler @('deploy') -MayFail
    }
    # Juste après la toute première publication, Cloudflare ne « voit » pas encore le serveur qu'il vient de
    # recevoir (« This Worker does not exist on your account ») et wrangler abandonne : on réessaie.
    $try = 0
    while ($script:wranglerCode -ne 0 -and $out -match 'does not exist on your account' -and $try -lt 5) {
        $try++
        Write-Tip "Cloudflare ne voit pas encore le serveur qu'il vient de recevoir (normal juste après la première publication)."
        Write-Tip "Nouvel essai dans 20 secondes ($try/5)..."
        Start-Sleep -Seconds 20
        $out = Invoke-Wrangler @('deploy') -MayFail
    }
    if ($script:wranglerCode -ne 0) {
        if ($out -match 'register a workers\.dev subdomain') {
            throw ("Il manque toujours le sous-domaine workers.dev. Choisis-le sur https://dash.cloudflare.com " +
                   "(menu Workers & Pages), puis relance ce script.")
        }
        throw "La publication a échoué (code $($script:wranglerCode)) : voir le message de wrangler ci-dessus."
    }
    $url = [regex]::Match($out, 'https://[a-z0-9.-]+\.workers\.dev').Value
    if (-not $url) { throw "Adresse du serveur introuvable dans la réponse de wrangler (ci-dessus)." }
    Write-Host "Serveur en ligne : $url"

    Write-Step "5/5 L'adresse dans le jeu (reglages\reseau.txt), et un essai"
    $cfg = Join-Path $PSScriptRoot '..\reglages\reseau.txt'
    $text = Get-Content -Raw -Encoding UTF8 $cfg
    $text = [regex]::Replace($text, '(?m)^adresse\s*\|[^#\r\n]*', ('adresse | ' + $url + '   '))
    [IO.File]::WriteAllText((Resolve-Path $cfg), $text, (New-Object Text.UTF8Encoding $false))
    Write-Host "Adresse notée dans reglages\reseau.txt."
    $answer = 0
    for ($i = 1; $i -le 9 -and $answer -ne 403 -and $answer -ne 500; $i++) {
        $answer = Get-ServerAnswer $url
        if ($answer -ne 403 -and $answer -ne 500) {
            Write-Host "Le serveur n'est pas encore joignable (un sous-domaine neuf met parfois quelques minutes) : nouvel essai dans 20 s ($i/9)..."
            Start-Sleep -Seconds 20
        }
    }
    Write-Host ''
    if ($answer -eq 403) {
        Write-Host "Le serveur répond et sa base est prête." -ForegroundColor Green
        Write-Host "Fini. Il reste à réexporter le jeu et à le publier : dis-le moi (« réexporte »)." -ForegroundColor Green
    } elseif ($answer -eq 500) {
        Write-Tip "Le serveur répond, mais sa base n'a pas ses tables : relance ce script (il les recrée), puis copie-moi le message s'il recommence."
    } else {
        Write-Tip "Le serveur est publié mais pas encore joignable (code $answer). Ce n'est pas grave : dis-moi « réexporte », je vérifierai de mon côté."
    }
} finally {
    [Console]::OutputEncoding = $oldEncoding
}
