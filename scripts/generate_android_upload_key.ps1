<#
.SYNOPSIS
Genera la clave privada usada para firmar las versiones Android de CUAC.

.DESCRIPTION
Crea el keystore de subida, el archivo privado key.properties que Gradle lee al
firmar y un certificado público PEM. El keystore y key.properties contienen
secretos: deben mantenerse fuera del control de versiones y respaldarse en una
ubicación segura. El certificado PEM sí puede compartirse públicamente.

.PARAMETER KeytoolPath
Ruta opcional al ejecutable keytool.exe. Si se omite, el script intenta
resolverlo desde JAVA_HOME y luego desde los comandos disponibles del sistema.

.PARAMETER Force
Permite reemplazar los tres archivos de firma en sus rutas exactas. Utilizarlo
invalida la clave anterior si no existe un respaldo recuperable.
#>
[CmdletBinding()]
param(
    [string]$KeytoolPath = '',
    [switch]$Force
)

# Cualquier fallo detiene el proceso para evitar un conjunto parcial de archivos.
$ErrorActionPreference = 'Stop'

# Todas las rutas se construyen desde la ubicación del script y no dependen del
# directorio actual de la terminal.
$projectRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..')
)
$androidDirectory = Join-Path $projectRoot 'android'
$keystorePath = Join-Path $androidDirectory 'app\cuac-upload-keystore.jks'
$propertiesPath = Join-Path $androidDirectory 'key.properties'
$certificatePath = Join-Path $androidDirectory 'upload_certificate.pem'

# La protección predeterminada evita sobrescribir por accidente la identidad con
# la que ya se publicaron versiones de la aplicación.
if ((Test-Path -LiteralPath $keystorePath) -and -not $Force) {
    throw "La clave ya existe en $keystorePath. No se sobrescribió."
}

# keytool forma parte del JDK. Se prioriza la ruta explícita, luego JAVA_HOME y
# finalmente la resolución normal de comandos del sistema.
if ([string]::IsNullOrWhiteSpace($KeytoolPath)) {
    if ($env:JAVA_HOME) {
        $KeytoolPath = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
    } else {
        $command = Get-Command keytool.exe -ErrorAction SilentlyContinue
        if ($command) {
            $KeytoolPath = $command.Source
        }
    }
}

if (-not $KeytoolPath -or -not (Test-Path -LiteralPath $KeytoolPath)) {
    throw 'No se encontró keytool. Indica -KeytoolPath o configura JAVA_HOME.'
}

# `-Force` elimina únicamente los tres destinos conocidos antes de regenerarlos;
# esta acción es irreversible si la clave privada no está respaldada.
if ($Force) {
    foreach ($path in @($keystorePath, $propertiesPath, $certificatePath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

# La contraseña se obtiene de un generador criptográficamente seguro y se adapta
# a caracteres seguros para argumentos y archivos de propiedades.
$passwordBytes = [byte[]]::new(32)
$randomNumberGenerator =
    [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $randomNumberGenerator.GetBytes($passwordBytes)
} finally {
    $randomNumberGenerator.Dispose()
}
$password = [Convert]::ToBase64String($passwordBytes).
    TrimEnd('=').
    Replace('+', '-').
    Replace('/', '_')

# Configura una clave RSA de subida válida por aproximadamente 27 años. El alias
# y los datos del sujeto deben mantenerse alineados con la configuración Gradle.
$keytoolArguments = @(
    '-genkeypair',
    '-noprompt',
    '-keystore', $keystorePath,
    '-storetype', 'JKS',
    '-storepass', $password,
    '-keypass', $password,
    '-alias', 'cuac-upload',
    '-keyalg', 'RSA',
    '-keysize', '2048',
    '-validity', '10000',
    '-dname', 'CN=CUAC, OU=Mobile, O=EBASSK, L=Bogota, ST=Cundinamarca, C=CO'
)

# Ejecuta keytool sin exponer la contraseña en los mensajes impresos y valida su
# código de salida antes de continuar.
& $KeytoolPath @keytoolArguments
if ($LASTEXITCODE -ne 0) {
    throw "keytool falló con código $LASTEXITCODE."
}

# Gradle necesita estas propiedades privadas para localizar y desbloquear el
# keystore. Se escribe UTF-8 sin BOM para máxima compatibilidad con Java.
$propertiesContent = @"
storePassword=$password
keyPassword=$password
keyAlias=cuac-upload
storeFile=cuac-upload-keystore.jks
"@
[System.IO.File]::WriteAllText(
    $propertiesPath,
    $propertiesContent,
    [System.Text.UTF8Encoding]::new($false)
)

# El certificado exportado contiene solo la clave pública y permite registrar o
# verificar la identidad de firma sin compartir el keystore ni su contraseña.
& $KeytoolPath `
    -exportcert `
    -rfc `
    -keystore $keystorePath `
    -storepass $password `
    -alias 'cuac-upload' `
    -file $certificatePath
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo exportar el certificado público: $LASTEXITCODE."
}

# Solo se informan rutas; ningún mensaje revela la contraseña generada.
Write-Host 'Clave de subida generada correctamente.'
Write-Host "Keystore privado: $keystorePath"
Write-Host "Propiedades privadas: $propertiesPath"
Write-Host "Certificado público: $certificatePath"
Write-Warning 'Respalda el keystore y key.properties fuera del equipo.'
