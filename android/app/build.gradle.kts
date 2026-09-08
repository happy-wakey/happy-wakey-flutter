import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

val requiredReleaseEnvironment: (String) -> String = { name ->
    val value = providers.environmentVariable(name).orNull?.trim().orEmpty()
    if (value.isEmpty()) {
        throw GradleException(
            "$name is required for Android release builds. " +
                "Provision it through the protected mobile-release environment.",
        )
    }
    value
}

val releaseSigningValues = if (releaseTaskRequested) {
    val keystorePath = requiredReleaseEnvironment("HAPPY_WAKEY_ANDROID_KEYSTORE_PATH")
    val keystoreFile = file(keystorePath)
    if (!keystoreFile.isFile) {
        throw GradleException(
            "HAPPY_WAKEY_ANDROID_KEYSTORE_PATH must reference an existing non-committed keystore file.",
        )
    }

    mapOf(
        "storePath" to keystoreFile.absolutePath,
        "storePassword" to requiredReleaseEnvironment("HAPPY_WAKEY_ANDROID_KEYSTORE_PASSWORD"),
        "keyAlias" to requiredReleaseEnvironment("HAPPY_WAKEY_ANDROID_KEY_ALIAS"),
        "keyPassword" to requiredReleaseEnvironment("HAPPY_WAKEY_ANDROID_KEY_PASSWORD"),
    )
} else {
    emptyMap()
}

android {
    namespace = "com.happywakey.happy_wakey"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // This is the durable Google Play / Android developer-verification identity.
        applicationId = "com.happywakey.happy_wakey"
        // Health Connect requires API 26; older Android builds retain the
        // unsupported-platform empty state through the web/desktop targets.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (releaseTaskRequested) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("storePath"))
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseTaskRequested) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
