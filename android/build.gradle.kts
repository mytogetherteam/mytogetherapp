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

    // Automatically set namespace for plugins like flutter_app_badger that don't specify one
    afterEvaluate {
        val androidExtension = project.extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val namespaceMethod = androidExtension.javaClass.methods.find { it.name == "getNamespace" }
                if (namespaceMethod != null && namespaceMethod.invoke(androidExtension) == null) {
                    val setNamespaceMethod = androidExtension.javaClass.methods.find { it.name == "setNamespace" }
                    setNamespaceMethod?.invoke(androidExtension, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignore
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
