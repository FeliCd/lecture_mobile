allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // file_picker 11 skips KGP on AGP 9, but this Flutter project explicitly
    // disables built-in Kotlin for Firebase plugins. Compile its Kotlin sources.
    if (project.name == "file_picker" && project.findProperty("android.builtInKotlin") == "false") {
        project.plugins.withId("com.android.library") {
            project.plugins.apply("org.jetbrains.kotlin.android")
            project.extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
