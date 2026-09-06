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
    // plugins que todavía declaran un jvmTarget viejo a mano.
    //
    // IMPORTANTE: para los módulos Android (app y plugins) hay que setear
    // `android.compileOptions`, NO las propiedades del task JavaCompile
    // directamente — AGP recalcula esas propiedades del task a partir de
    // `compileOptions` durante su propio afterEvaluate, así que un
    // `tasks.withType<JavaCompile>` corriendo antes queda pisado. Por eso
    // esto también va en un afterEvaluate (para ejecutar después del
    // afterEvaluate que registra cada plugin, no antes).
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { androidExt ->
            androidExt.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExt.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
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
