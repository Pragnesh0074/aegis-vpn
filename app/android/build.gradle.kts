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

// Pin every plugin to the compileSdk this Flutter version ships against (36).
//
// `flutter_secure_storage` hardcodes `compileSdk = 37`, which AGP resolves to a
// `platforms/android-37` directory that no longer exists — Google now publishes
// android-37.0, 37.1 and 37.2 instead, so the build fails with "Failed to find
// target with hash string 'android-37'". Compiling the plugin against 36 is safe:
// it declares minSdk 24 and uses no API-37 symbols.
//
// This must run BEFORE the `evaluationDependsOn` block below, which evaluates
// projects eagerly and would make a later `afterEvaluate` too late to register.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        android.javaClass.methods
            .firstOrNull {
                it.name == "setCompileSdkVersion" &&
                    it.parameterTypes.singleOrNull() == Int::class.javaPrimitiveType
            }
            ?.invoke(android, 36)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
