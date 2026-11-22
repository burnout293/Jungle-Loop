# Jungle Loop — la clé qui signe les envois au Play Store (à lancer par toi, une fois).
#
#   powershell -ExecutionPolicy Bypass -File store\play\cle-android.ps1
#
# Elle est créée HORS du dépôt (dans Documents\Projects\Archives\Jungle-Loop\android), avec keytool, l'outil du
# JDK 17 (à installer d'abord, voir store\README.md). keytool demande lui-même les mots de passe : ils ne
# passent ni par ce script ni par moi. Garde la clé et ses mots de passe en lieu sûr (une copie hors de ce PC) :
# avec la « Signature d'application par Google Play », perdre cette clé d'envoi se répare auprès de Google,
# mais c'est long.
# Ensuite, dans Godot : Projet › Exporter › Android › Keystore › Release : le chemin du fichier, l'alias
# « jungleloop » ; les mots de passe se tapent là, ou dans les variables d'environnement
# GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD au moment d'exporter.

$ErrorActionPreference = 'Stop'
$dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Projects\Archives\Jungle-Loop\android'
if (Test-Path 'D:\BULY-PCP\Documents\Projects\Archives') { $dir = 'D:\BULY-PCP\Documents\Projects\Archives\Jungle-Loop\android' }
$keystore = Join-Path $dir 'jungleloop-envoi.keystore'
if (Test-Path $keystore) {
  Write-Host "Une clé existe déjà : $keystore (rien n'est fait)."
  exit 0
}
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool -and $env:JAVA_HOME) { $keytool = Get-Command (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -ErrorAction SilentlyContinue }
if (-not $keytool) {
  Write-Host 'keytool introuvable : installe d''abord le JDK 17 (store\README.md), puis relance.'
  exit 1
}
New-Item -ItemType Directory -Force $dir | Out-Null
& $keytool.Source -genkeypair -v -keystore $keystore -alias jungleloop -keyalg RSA -keysize 4096 -validity 10000 `
  -dname 'CN=Jungle Loop, O=Jungle Loop, C=FR'
Write-Host ''
Write-Host "Clé créée : $keystore (alias jungleloop). Ne la mets jamais dans le dépôt."
