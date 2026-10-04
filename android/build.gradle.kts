allprojects {
    repositories {
        maven {
            url = uri(rootProject.file("local-maven"))
        }
        google()
        mavenCentral()
    }

    configurations.configureEach {
        resolutionStrategy.dependencySubstitution {
            substitute(module("androidx.datastore:datastore-core-android"))
                .using(module("com.ghostheart5.rebuilt:datastore-core-android-symbolized:1.1.7-gh1"))
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
