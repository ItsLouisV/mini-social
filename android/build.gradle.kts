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

subprojects {
    val configureNamespace: Project.() -> Unit = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)
                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val defaultNamespace = "dev.isar.${name.replace("-", "_")}"
                    setNamespace.invoke(android, defaultNamespace)
                }
            } catch (_: Exception) {
            }
        }
    }

    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8)
            apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8)
        }
    }
}

// Force all subprojects to use compileSdk >= 36
// to satisfy plugin requirements (connectivity_plus, app_links, etc. require SDK 35-36).
subprojects {
    val configureCompileSdk: Project.() -> Unit = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getCompileSdk = android.javaClass.getMethod("getCompileSdkVersion")
                val current = getCompileSdk.invoke(android) as? Int ?: 0
                if (current < 36) {
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdk.invoke(android, 36)
                }
            } catch (_: Exception) {}
        }
    }

    if (state.executed) {
        configureCompileSdk()
    } else {
        afterEvaluate {
            configureCompileSdk()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
