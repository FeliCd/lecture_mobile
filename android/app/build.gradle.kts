import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val cloudDartDefines = (project.findProperty("dart-defines") as? String ?: "")
    .split(",").filter { it.isNotEmpty() }.mapNotNull {
        runCatching { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }.getOrNull()
    }.associate { val pair = it.split("=", limit = 2); pair[0] to pair.getOrElse(1) { "" } }
if (cloudDartDefines["USE_EMULATORS"] != "true" && file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}
if (cloudDartDefines["FIREBASE_PROJECT_ID"] != null && cloudDartDefines["USE_EMULATORS"] != "true" && !file("google-services.json").exists()) {
    throw GradleException("Download android/app/google-services.json for this Firebase app; see docs/LAB3_GROUPS_IMPLEMENTATION.md")
}

val releaseKeys = Properties()
val releaseKeyFile = rootProject.file("key.properties")
if (releaseKeyFile.exists()) releaseKeyFile.inputStream().use { releaseKeys.load(it) }

android {
    buildFeatures { resValues = true }
    namespace = "vn.edu.fpt.lecturer_companion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        if (cloudDartDefines["USE_EMULATORS"] == "true") {
            // Native SDK requires a build id even when collection is disabled.
            // This local marker never represents a Firebase Console upload.
            resValue("string", "com.google.firebase.crashlytics.mapping_file_id", "emulator-local-collection-disabled")
        }
        applicationId = "vn.edu.fpt.lecturer_companion"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (releaseKeyFile.exists()) {
            create("release") {
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
                storeFile = file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            if (releaseKeyFile.exists()) signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Never silently sign a release with the development key.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && !releaseKeyFile.exists()) {
        throw GradleException("Release signing requires android/key.properties; see README.md")
    }
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
flutter { source = "../.." }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
