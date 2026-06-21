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
    
    val setJvm17 = Action<Project> {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
                compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (e: Exception) {}
        }
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

    if (state.executed) {
        setJvm17.execute(this)
    } else {
        afterEvaluate(setJvm17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
