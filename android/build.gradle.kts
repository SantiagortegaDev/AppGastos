// build.gradle.kts (root) — normalmente lo genera `flutter create .` en el
// paso "Scaffold missing Android files" del CI, pero lo commiteamos para
// poder forzar un JVM target consistente en TODOS los subproyectos
// (incluidos los plugins de terceros). Sin esto, plugins como
// `flutter_timezone` fallan con AGP reciente:
//   "Inconsistent JVM-target compatibility detected for tasks
//    'compileReleaseJavaWithJavac' (11) and 'compileReleaseKotlin' (1.8)".

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Fuerza JVM 17 tanto para javac como para kotlinc en todos los módulos
    // (app + cada plugin), evitando el mismatch que rompe el build con
    // plugins que todavía declaran un jvmTarget viejo (1.8) a mano.
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
