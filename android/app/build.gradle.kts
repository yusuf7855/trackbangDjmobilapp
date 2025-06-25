// android/app/build.gradle.kts - Firebase + bildirimler + tüm düzeltmelerle

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ Firebase Google services plugin (Firebase talimatı)
    id("com.google.gms.google-services")
}

dependencies {
    // ✅ Firebase BoM (Firebase talimatı)
    implementation(platform("com.google.firebase:firebase-bom:33.15.0"))

    // ✅ Firebase dependencies (Firebase talimatı)
    implementation("com.google.firebase:firebase-analytics")

    // ✅ EKLENDİ: Firebase Messaging (bildirimler için gerekli)
    implementation("com.google.firebase:firebase-messaging")

    // ✅ EKLENDİ: Core library desugaring (flutter_local_notifications için gerekli)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

android {
    // ✅ Namespace MainActivity ile uyumlu
    namespace = "com.example.djmobilapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ EKLENDİ: Core library desugaring etkinleştirme
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // ✅ ApplicationID MainActivity ve yeni Firebase app ile uyumlu
        applicationId = "com.example.djmobilapp"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ EKLENDİ: MultiDex desteği
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}