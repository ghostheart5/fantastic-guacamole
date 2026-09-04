"""Real AGP configuration check with synthetic values; not a signed-build test.

Run with an installed Gradle 8.14.3 executable as the only argument.
Requires cached AGP 8.11.1 and Android SDK; offline, no application compilation.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from android_candidate_build import SIGNING_BOOTSTRAP


def verify(gradle):
    hook = Path(__file__).with_name("candidate-signing.init.gradle").resolve()
    with tempfile.TemporaryDirectory(prefix="chronospark-agp-signing-check-") as folder:
        root = Path(folder)
        (root / "app").mkdir()
        (root / "key.properties").write_text(SIGNING_BOOTSTRAP)
        (root / "settings.gradle").write_text('''
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
rootProject.name = 'candidate-signing-check'
include ':app'
''')
        (root / "app/build.gradle").write_text('''
plugins { id 'com.android.application' version '8.11.1' }
def bootstrap = new Properties()
rootProject.file('key.properties').withInputStream { bootstrap.load(it) }
android {
    namespace 'com.ghostheart5.signingcheck'
    compileSdk 36
    defaultConfig { minSdk 23 }
    signingConfigs {
        release {
            storePassword bootstrap.storePassword
            keyPassword bootstrap.keyPassword
            keyAlias bootstrap.keyAlias
            storeFile rootProject.file(bootstrap.storeFile)
        }
    }
    buildTypes { release { signingConfig signingConfigs.release } }
}
tasks.register('verifyCandidateSigning') {
    doLast {
        def signing = android.buildTypes.release.signingConfig
        assert signing.storePassword == System.getenv('ANDROID_STORE_PASSWORD')
        assert signing.keyPassword == System.getenv('ANDROID_KEY_PASSWORD')
        assert signing.keyAlias == System.getenv('ANDROID_KEY_ALIAS')
        assert signing.storeFile == rootProject.file('app/upload-keystore.jks')
        println 'PASS: real AGP release configuration received environment values'
    }
}
''')
        env = os.environ.copy()
        # Synthetic probes exercise punctuation/Unicode without real credentials.
        env.update(ANDROID_STORE_PASSWORD="probe store:=\\#!é",
                   ANDROID_KEY_PASSWORD="probe key:=\\#!é",
                   ANDROID_KEY_ALIAS="probe-alias")
        args = [gradle, "--offline", "--no-daemon", "--no-configuration-cache",
                "--console=plain", "-I", str(hook), ":app:verifyCandidateSigning"]
        result = subprocess.run(args, cwd=root, env=env, text=True, capture_output=True)
        if result.returncode:
            print(result.stdout + result.stderr)
            raise RuntimeError("Real AGP signing configuration check failed")
        print("PASS: real AGP 8.11.1 injected all signing fields without compiling an app")
        del env["ANDROID_KEY_PASSWORD"]
        result = subprocess.run(args, cwd=root, env=env, text=True, capture_output=True)
        if result.returncode == 0 or "Missing candidate signing environment variable: ANDROID_KEY_PASSWORD" not in result.stdout + result.stderr:
            raise RuntimeError("Missing signing variable did not fail closed")
        print("PASS: missing key password fails configuration before task execution")


if __name__ == "__main__":
    verify(sys.argv[1])
