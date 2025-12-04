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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

//plugins {
//    id("com.android.application")
//    id("org.jetbrains.kotlin.android") // Keep this if you're using Kotlin for native Android code
//    //id("dev.flutter.flutter-gradle-plugin") // Add this line
//}
//
//allprojects {
//    repositories {
//        google()
//        mavenCentral()
//    }
//}
//
//val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
//rootProject.layout.buildDirectory.value(newBuildDir)
//
//subprojects {
//    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
//    project.layout.buildDirectory.value(newSubprojectBuildDir)
//}
//subprojects {
//    project.evaluationDependsOn(":app")
//}

//tasks.register<Delete>("clean") {
//    delete(rootProject.layout.buildDirectory)
//}

//android {
//    namespace = "com.example.personal_assistant"
//    compileSdk = 34
//    ndkVersion = "27.0.12077973"
//
//    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_11
//        targetCompatibility = JavaVersion.VERSION_11
//    }
//
//    kotlinOptions {
//        jvmTarget = JavaVersion.VERSION_11.toString()
//    }
//
//    defaultConfig {
//        applicationId = "com.example.personal_assistant"
//        minSdk = 24
//        targetSdk = 34
//        versionCode = 1
//        versionName = "1.0"
//
//        // Increase heap size for large assets
//        multiDexEnabled = true
//    }
//
//    // Optimize for large assets
//    packagingOptions {
//        pickFirsts.addAll(listOf( // Use addAll to add multiple items
//            "**/libc++_shared.so",
//            "**/libjsc.so",
//            "**/libc++.so",
//            "**/libfbjni.so"
//        ))
//
//        excludes.addAll(listOf( // Use addAll here too
//            "META-INF/DEPENDENCIES",
//            "META-INF/LICENSE",
//            "META-INF/LICENSE.txt",
//            "META-INF/NOTICE",
//            "META-INF/NOTICE.txt"
//        ))
//    }
//
//
//    buildTypes {
//        release {
//            // Optimize for size in release builds
//            isMinifyEnabled = true
//            isShrinkResources = true
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
//
//            signingConfig = signingConfigs.getByName("debug")
//        }
//        debug {
//            // Disable optimization in debug for faster builds
//            isMinifyEnabled = false
//            isShrinkResources = false
//        }
//    }
//}
//
//dependencies {
//    implementation("androidx.multidex:multidex:2.0.1")
//}

