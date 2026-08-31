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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Kotlin/Java JVM-target alignment. Plugins pin inconsistent targets
// (another_telephony: Java 11 with Kotlin left at KGP's 1.8 default;
// workmanager pins both at 8; the app and share_plus pin 17). Two levels:
//
// 1) DSL level (gradle.afterProject): fires after each subproject's build
//    script has run (final plugin-pinned values) but before AGP's
//    afterEvaluate consumes the android DSL to create tasks, so this
//    reliably rewrites every subproject's Java compile target to 17.
//    (:app is evaluated earlier via evaluationDependsOn, but already pins 17.)
// 2) Task level (configureEach): runs at task realization, after all plugin
//    afterEvaluate configuration, forcing Kotlin's jvmTarget to 17.
//
// The previous approach read the JavaCompile task eagerly in gradle.afterProject,
// which fires before AGP creates its tasks, so it never matched anything.
gradle.afterProject {
    val android = project.extensions.findByName("android")
    if (android is com.android.build.api.dsl.CommonExtension) {
        android.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
        android.compileOptions.targetCompatibility = JavaVersion.VERSION_17
    }
}
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
