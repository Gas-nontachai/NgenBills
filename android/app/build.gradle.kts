import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI supplies environment variables; local releases may use android/key.properties.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

// AGP may otherwise produce an unsigned APK when the signing values are absent.
tasks.configureEach {
    if (name == "preReleaseBuild") {
        doFirst {
            val requiredValues = mapOf(
                "ANDROID_KEYSTORE_PATH / storeFile" to signingValue("ANDROID_KEYSTORE_PATH", "storeFile"),
                "ANDROID_KEYSTORE_PASSWORD / storePassword" to signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword"),
                "ANDROID_KEY_ALIAS / keyAlias" to signingValue("ANDROID_KEY_ALIAS", "keyAlias"),
                "ANDROID_KEY_PASSWORD / keyPassword" to signingValue("ANDROID_KEY_PASSWORD", "keyPassword"),
            )
            val missing = requiredValues.filterValues { it == null }.keys
            check(missing.isEmpty()) {
                "Release signing is required. Configure environment variables or android/key.properties. Missing: ${missing.joinToString()}"
            }
            check(file(signingValue("ANDROID_KEYSTORE_PATH", "storeFile")!!).isFile) {
                "Release keystore file does not exist."
            }
        }
    }
}

android {
    namespace = "com.gasnontachai.ngenbills"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this application ID stable so releases update the same app.
        applicationId = "com.gasnontachai.ngenbills"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
            keyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
            storePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
            storeFile = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")?.let { file(it) }
        }
    }

    buildTypes {
        release {
            // Missing release credentials must fail signing, never fall back to a debug key.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
