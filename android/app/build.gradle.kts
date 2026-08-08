import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
// Las credenciales de firma se leen desde un archivo local excluido de Git.
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use(::load)
    }
}
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

// Una compilación release nunca debe continuar con una firma de depuración o
// sin la identidad de publicación configurada explícitamente.
if (releaseBuildRequested && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Falta android/key.properties. Ejecuta " +
            "scripts/generate_android_upload_key.ps1 antes de compilar release.",
    )
}

android {
    namespace = "com.ebassk.cuac"

    // Compila contra Android SDK 36 para usar las herramientas actuales.
    compileSdk = 36

    // Fija el NDK compatible con las dependencias nativas de TensorFlow Lite.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.ebassk.cuac"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // La configuración release solo existe cuando están disponibles las
        // propiedades privadas generadas por el script de firma.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Aplica la clave de subida únicamente a artefactos de publicación.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
