"""Liga a chave de assinatura (upload.jks, key.properties) ao build do Android.
Roda só no GitHub, depois do `flutter create`."""
p = 'android/app/build.gradle.kts'
s = open(p).read()
s = 'import java.util.Properties\n\n' + s
s = s.replace('android {', '''val keyProps = Properties().apply { load(rootProject.file("key.properties").inputStream()) }

android {''', 1)
s = s.replace('buildTypes {', '''signingConfigs {
        create("upload") {
            keyAlias = keyProps["keyAlias"] as String
            keyPassword = keyProps["keyPassword"] as String
            storeFile = file(keyProps["storeFile"] as String)
            storePassword = keyProps["storePassword"] as String
        }
    }
    buildTypes {''', 1)
assert 'signingConfigs.getByName("debug")' in s
s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("upload")')
open(p, 'w').write(s)
