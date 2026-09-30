plugins {
    alias(libs.plugins.agp.app) apply false
    alias(libs.plugins.kotlin) apply false
    alias(libs.plugins.compose.compiler) apply false
}

extra["androidMinSdkVersion"] = 31
extra["androidTargetSdkVersion"] = 37
extra["androidCompileSdkVersion"] = 37
extra["androidCompileSdkVersionMinor"] = 0
extra["androidBuildToolsVersion"] = "37.0.0"
extra["androidCompileNdkVersion"] = libs.versions.ndk.get()
extra["androidSourceCompatibility"] = JavaVersion.VERSION_21
extra["androidTargetCompatibility"] = JavaVersion.VERSION_21
extra["managerVersionCode"] = getVersionCode()
extra["managerVersionName"] = getVersionName()

fun getGitCommitCount(): Int {
    val process = Runtime.getRuntime().exec(arrayOf("git", "rev-list", "--count", "HEAD"))
    return process.inputStream.bufferedReader().use { it.readText().trim().toInt() }
}

fun getGitDescribe(): String {
    val process = Runtime.getRuntime().exec(arrayOf("git", "describe", "--tags", "--always"))
    return process.inputStream.bufferedReader().use { it.readText().trim() }
}

// How many commits this fork adds over upstream. Computed live when the
// official branch is reachable, otherwise taken from the cached
// .ksu-fork-offset that scripts/update-fork-offset.sh maintains.
fun getForkOffset(): Int {
    val repo = rootDir.parentFile
    try {
        val process = ProcessBuilder("git", "rev-list", "--count", "upstream/main..HEAD")
            .directory(repo)
            .redirectError(ProcessBuilder.Redirect.DISCARD)
            .start()
        val out = process.inputStream.bufferedReader().use { it.readText() }.trim()
        if (process.waitFor() == 0 && out.isNotEmpty()) return out.toInt()
    } catch (_: Exception) {
    }
    return try {
        java.io.File(rootDir, "../.ksu-fork-offset").readText().trim().toInt()
    } catch (_: Exception) {
        0
    }
}

fun getVersionCode(): Int {
    val commitCount = getGitCommitCount()
    return 30000 - getForkOffset() + commitCount
}

fun getVersionName(): String {
    return getGitDescribe()
}
