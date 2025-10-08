plugins {
    id("com.android.application")
    id("kotlin-android")               // si te da error, cámbialo por: id("org.jetbrains.kotlin.android")
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.petfyco"

    // Valores que provee el plugin de Flutter
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.petfyco"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Java 17 + desugaring para librerías core (requerido por flutter_local_notifications)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        release {
            // Config de firma de ejemplo (debug). Sustituye por tu firma release cuando la tengas.
            signingConfig = signingConfigs.getByName("debug")
            // Si usas shrinker/proguard, descomenta:
            // isMinifyEnabled = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring para usar APIs java.time y otras en minSdk bajos
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // (No agregues aquí dependencias de Flutter; las maneja pubspec.yaml)
}
