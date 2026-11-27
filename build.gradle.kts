plugins {
    java
    id("org.springframework.boot") version "4.1.3"
}

group = "org.sentiment"
version = "1.0.3"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(platform("org.springframework.boot:spring-boot-dependencies:4.1.3"))
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("com.github.vinhkhuc:jfasttext:0.5")
    implementation("com.microsoft.onnxruntime:onnxruntime:1.20.0")
    implementation("ai.djl.huggingface:tokenizers:0.39.0")
    runtimeOnly("io.micrometer:micrometer-registry-prometheus")

    testImplementation("org.springframework.boot:spring-boot-starter-test") {
        exclude(group = "org.skyscreamer", module = "jsonassert")
    }
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

    constraints {
        implementation("org.apache.tomcat.embed:tomcat-embed-core:11.0.29")
        implementation("org.apache.tomcat.embed:tomcat-embed-el:11.0.29")
        implementation("org.apache.tomcat.embed:tomcat-embed-websocket:11.0.29")
        implementation("ch.qos.logback:logback-classic:1.6.8")
        implementation("ch.qos.logback:logback-core:1.6.8")
        implementation("commons-codec:commons-codec:1.23.0")
    }
}

tasks.withType<JavaCompile>().configureEach {
    options.encoding = "UTF-8"
}

tasks.test {
    useJUnitPlatform()
}
