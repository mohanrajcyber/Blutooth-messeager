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

    // Force Flutter plugins (file_picker etc.) to compile against API 36.
    pluginManager.withPlugin("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            androidExt.javaClass.methods
                .find { it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 }
                ?.invoke(androidExt, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
