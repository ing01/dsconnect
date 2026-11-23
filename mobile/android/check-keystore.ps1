# Confere o keystore.properties contra o arquivo .jks SEM rodar o build:
# 2 segundos em vez de minutos. Mostra so OK/ERRO, os aliases e os fingerprints.
# NUNCA imprime senha.
#
# Uso (a partir de mobile\android):
#   powershell -ExecutionPolicy Bypass -File .\check-keystore.ps1

# 'Continue' de proposito: no Windows PowerShell 5.1, com 'Stop', cada linha que o keytool
# escreve na saida de erro (ex.: "senha incorreta") vira uma excecao e esconde a mensagem daqui.
$ErrorActionPreference = 'Continue'
$androidDir = $PSScriptRoot
$propsFile = Join-Path $androidDir 'keystore.properties'

function Fail($message) {
    Write-Host "ERRO: $message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $propsFile)) { Fail "keystore.properties nao encontrado em $androidDir" }

# O Gradle le este arquivo com java.util.Properties: a barra invertida e escape
# (\\ vira \, \t vira tab, \x vira x) e o espaco logo depois do '=' e ignorado.
# Aqui o valor e interpretado do mesmo jeito, para o teste valer para o build.
function ConvertFrom-JavaEscapes($text) {
    $result = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $text.Length; $i++) {
        $char = $text[$i]
        if ($char -ne '\' -or $i -eq $text.Length - 1) { [void]$result.Append($char); continue }
        $i++
        switch ($text[$i]) {
            't' { [void]$result.Append("`t") }
            'n' { [void]$result.Append("`n") }
            'r' { [void]$result.Append("`r") }
            'f' { [void]$result.Append("`f") }
            'u' {
                if ($i + 4 -lt $text.Length + 0 -and $text.Substring($i + 1, 4) -match '^[0-9a-fA-F]{4}$') {
                    [void]$result.Append([char][Convert]::ToInt32($text.Substring($i + 1, 4), 16)); $i += 4
                } else { [void]$result.Append('u') }
            }
            default { [void]$result.Append($text[$i]) }
        }
    }
    $result.ToString()
}

# Nao usa ConvertFrom-StringData, que consome as barras invertidas das senhas.
$config = @{}
foreach ($line in Get-Content $propsFile) {
    if ($line -match '^\s*[#!]' -or $line -match '^\s*$') { continue }
    $separator = $line.IndexOf('=')
    if ($separator -gt 0) {
        $config[$line.Substring(0, $separator).Trim()] = ConvertFrom-JavaEscapes ($line.Substring($separator + 1).TrimStart())
    }
}
foreach ($key in 'storeFile', 'storePassword', 'keyAlias', 'keyPassword') {
    if (-not $config.ContainsKey($key) -or [string]::IsNullOrEmpty($config[$key])) { Fail "falta '$key' no keystore.properties" }
}

# O Gradle resolve `storeFile` a partir de android\app\ (o ../ sai para android\).
$storeFile = $config['storeFile']
if (-not [IO.Path]::IsPathRooted($storeFile)) { $storeFile = Join-Path (Join-Path $androidDir 'app') $storeFile }
$storeFile = [IO.Path]::GetFullPath($storeFile)
Write-Host "Arquivo que o build usa: $storeFile"
if (-not (Test-Path $storeFile)) { Fail 'o arquivo .jks nao existe nesse caminho (veja o storeFile; ele e relativo a android\app\)' }

# keytool
$keytool = $null
$command = Get-Command keytool -ErrorAction SilentlyContinue
if ($command) { $keytool = $command.Source }
if (-not $keytool -and $env:JAVA_HOME) { $candidate = Join-Path $env:JAVA_HOME 'bin\keytool.exe'; if (Test-Path $candidate) { $keytool = $candidate } }
if (-not $keytool) {
    $keytool = @(
        (Get-ChildItem 'C:\Program Files\Microsoft\jdk-*\bin\keytool.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName),
        'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $keytool) { Fail 'keytool nao encontrado (instale um JDK ou defina JAVA_HOME)' }

# As senhas vao por variavel de ambiente (nao aparecem na linha de comando) e saem ao final.
$env:KS_CHECK_STORE_PASS = $config['storePassword']
$env:KS_CHECK_KEY_PASS = $config['keyPassword']
try {
    $listing = & $keytool -list -keystore $storeFile -storepass:env KS_CHECK_STORE_PASS 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) {
        Fail 'a storePassword NAO abre este arquivo (ou o arquivo nao e um keystore valido). Digite de novo a senha, sem aspas nem espaco no fim.'
    }
    Write-Host 'OK: storePassword abre o arquivo.' -ForegroundColor Green

    $aliases = @($listing | ForEach-Object { if ($_ -match '^([^,]+),.*PrivateKeyEntry') { $Matches[1].Trim() } })
    Write-Host ("Aliases de chave no arquivo: " + ($aliases -join ', '))

    $alias = $config['keyAlias']
    if ($aliases -notcontains $alias) {
        Fail "o keyAlias '$alias' NAO existe neste arquivo. Use um destes: $($aliases -join ', ') (alias e um nome curto, nao o nome do arquivo)"
    }
    Write-Host "OK: keyAlias '$alias' existe." -ForegroundColor Green

    # certreq exige a senha da CHAVE (nao so a do arquivo); o pedido gerado e descartado.
    $temp = [IO.Path]::GetTempFileName()
    try {
        $certreq = & $keytool -certreq -alias $alias -keystore $storeFile -storepass:env KS_CHECK_STORE_PASS -keypass:env KS_CHECK_KEY_PASS -file $temp 2>&1 | ForEach-Object { "$_" }
        if ($LASTEXITCODE -ne 0) { Fail 'a keyPassword NAO abre a chave deste alias (ela pode ser diferente da storePassword).' }
        # Em keystore PKCS12 o keytool IGNORA uma keyPassword diferente (e avisa), mas o Gradle nao ignora.
        if ($config['keyPassword'] -cne $config['storePassword'] -and ($certreq -join ' ') -match 'PKCS12') {
            Fail 'este keystore e PKCS12: a keyPassword tem de ser IGUAL a storePassword (o Gradle recusa se forem diferentes).'
        }
    } finally {
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
    }
    Write-Host 'OK: keyPassword abre a chave.' -ForegroundColor Green

    Write-Host ''
    Write-Host 'Fingerprints do certificado (compare com a Google Play -> Integridade do app -> chave de upload):'
    & $keytool -list -v -alias $alias -keystore $storeFile -storepass:env KS_CHECK_STORE_PASS 2>&1 |
        ForEach-Object { "$_" } | Where-Object { $_ -match 'SHA-?1|SHA-?256' } | ForEach-Object { '  ' + $_.Trim() }
    Write-Host ''
    Write-Host 'Tudo certo: o build deve passar da etapa de assinatura.' -ForegroundColor Green
} finally {
    Remove-Item Env:KS_CHECK_STORE_PASS -ErrorAction SilentlyContinue
    Remove-Item Env:KS_CHECK_KEY_PASS -ErrorAction SilentlyContinue
}
