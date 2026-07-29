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

// Force all Flutter plugins (e.g. file_picker) to compile against API 36.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            androidExt.javaClass.methods
                .find { it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 }
                ?.invoke(androidExt, 36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
