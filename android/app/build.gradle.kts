plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") // Google Services plugin for Firebase
    // END: FlutterFire Configuration
    id("kotlin-android") // Kotlin Android plugin
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin") // Flutter Gradle plugin
}

android {
    // Defines the package name for your Android application
    namespace = "com.example.steps4perks"

    // Sets the compile SDK version based on Flutter's configuration
    compileSdk = 35

    // Specifies the NDK (Native Development Kit) version to use.
    // Force a specific NDK version for consistency across builds if needed.
    ndkVersion = "27.0.12077973"

    // Configures Java compatibility settings
    compileOptions {
        // Sets the Java source code compatibility to Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        // Sets the target Java bytecode compatibility to Java 17
        targetCompatibility = JavaVersion.VERSION_17
        // Enables core library desugaring for Java 8+ features on older Android versions
        isCoreLibraryDesugaringEnabled = true
    }

    // Configures Kotlin specific options
    kotlinOptions {
        // Sets the JVM target version for Kotlin compilation to 17, aligning with Java 17
        jvmTarget = "17"
    }

    defaultConfig {
        // Defines the unique application ID for your app on Google Play Store
        applicationId = "com.example.steps4perks"

        // Overrides Flutter's default minSdkVersion to 23.
        // This is necessary for many Firebase features, especially Firebase Authentication.
        minSdk = 23
        // Sets the target SDK version based on Flutter's configuration
        targetSdk = flutter.targetSdkVersion
        // Sets the version code for your application (used for internal tracking/updates)
        versionCode = flutter.versionCode
        // Sets the version name for your application (user-visible version)
        versionName = flutter.versionName

        // Enables MultiDex. Crucial for apps with many methods (like Firebase apps)
        // to avoid the 65k method limit on older Android versions.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Configuration for the release build type.
            // TODO: Add your own signing config for release builds for security.
            // For now, it uses the debug signing config for convenience during development (`flutter run --release`).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Dependency required for core library desugaring to make Java 8+ features available
    // on devices running older Android versions.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    // Specifies the path to your Flutter project's root directory.
    source = "../.."
}