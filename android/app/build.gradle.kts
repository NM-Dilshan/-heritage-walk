import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional real Meta values live in ignored android/local.properties.
// No App Secret belongs in a client application.
val authProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val facebookAppId = authProperties.getProperty("heritagewalk.facebook.appId", "").trim()
val facebookClientToken = authProperties.getProperty("heritagewalk.facebook.clientToken", "").trim()
val facebookConfigured = facebookAppId.matches(Regex("[0-9]+")) && facebookClientToken.isNotEmpty()

android {
    buildFeatures { resValues = true }
    namespace = "lk.heritagewalk.heritage_walk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        resValue("string", "facebook_app_id", if (facebookConfigured) facebookAppId else "")
        resValue("string", "facebook_client_token", if (facebookConfigured) facebookClientToken else "")
        resValue("string", "facebook_login_protocol_scheme", if (facebookConfigured) "fb$facebookAppId" else "")
        resValue("bool", "facebook_configured", facebookConfigured.toString())
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "lk.heritagewalk.heritage_walk"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
