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

    // Plugins like file_picker must compile against API 36 (no evaluationDependsOn — it breaks afterEvaluate).
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            ext.javaClass.methods
                .find { it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 }
                ?.invoke(ext, 36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
