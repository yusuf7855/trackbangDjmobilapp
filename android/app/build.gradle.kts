// android/app/build.gradle.kts - Firebase + bildirimler + imzalama + tüm düzeltmelerle

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ Firebase Google services plugin (Firebase talimatı)
    id("com.google.gms.google-services")
}

// ✅ EKLENDİ: Keystore properties okuma
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    // ✅ EKLENDİ: MultiDex desteği
    implementation("androidx.multidex:multidex:2.0.1")
}

android {
    // ✅ Namespace MainActivity ile uyumlu
    namespace = "com.trackbang.djmobilapp"
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

    // ✅ EKLENDİ: İmzalama yapılandırmaları
    signingConfigs {
        create("release") {
            if (keystoreProperties.containsKey("keyAlias")) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        // ✅ ApplicationID MainActivity ve yeni Firebase app ile uyumlu
        applicationId = "com.trackbang.djmobilapp"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ EKLENDİ: MultiDex desteği
        multiDexEnabled = true
    }

    buildTypes {
        getByName("debug") {
            // Debug build için varsayılan ayarlar
            isDebuggable = true
            isMinifyEnabled = false
        }

        getByName("release") {
            // ✅ DÜZELTME: Release build için güvenli imzalama
            signingConfig = if (keystoreProperties.containsKey("keyAlias")) {
                signingConfigs.getByName("release")
            } else {
                // Keystore yoksa debug imzalama kullan (geliştirme için)
                signingConfigs.getByName("debug")
            }

            // ✅ EKLENDİ: Release optimizasyonları
            isMinifyEnabled = true
            isShrinkResources = true

            // ✅ EKLENDİ: ProGuard kuralları
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ✅ EKLENDİ: Dil desteği (opsiyonel)
    bundle {
        language {
            enableSplit = false
        }
    }
}

flutter {
    source = "../.."
}