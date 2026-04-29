plugins {
    id("com.android.application")
}

android {
    namespace = "com.opencomputer.client"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.opencomputer.client"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }
}
