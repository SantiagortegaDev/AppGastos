// build.gradle.kts (app-level).
//
// Compatible con AGP 9.0+ (que es el default en `flutter create` reciente).
// Las líneas marcadas con `[TILE]` son los cambios mínimos necesarios para
// que el Quick Settings Tile funcione:
//   - targetSdk 34 (para ACTION_QUICK_SETTINGS_ADD_TILE requiere API 33+).
//   - No se requieren dependencias adicionales: TileService es parte del
//     framework Android, no de AndroidX.

import java.util.Properties
import java.io.FileInputStream

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter DEBE aplicarse después de Android y Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Lee versionCode/versionName desde local.properties (lo escribe Flutter).
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.appgastos"
    compileSdk = 34  // [TILE] 34 o superior

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // [AGP 9.0] Reemplaza al viejo `kotlinOptions { jvmTarget = "17" }`.
    // Ahora se usa el DSL `compilerOptions` del plugin Kotlin Gradle.
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }

    defaultConfig {
        applicationId = "com.example.appgastos"
        minSdk = 21
        targetSdk = 34  // [TILE] API 33+ requerido para ACTION_QS_ADD_TILE
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            // En producción usa tu propio keystore. Para pruebas esto basta.
            signingConfig = signingConfigs.getByName("debug")
            // [AGP 9.0] `minifyEnabled` y `shrinkResources` se mantienen pero
            // requieren importar la prop correctamente. En AGP 9.0 son
            // propiedades directas del BuildType, accesibles sin prefijo.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
