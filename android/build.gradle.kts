
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    layout.buildDirectory.set(
        rootProject.layout.buildDirectory.dir(name)
    )
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
