# Build + run in one image (Java 21)
FROM eclipse-temurin:21-jdk-alpine

WORKDIR /app
RUN apk add --no-cache maven

# Cache deps first
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline

# Copy source and build
COPY src ./src
RUN mvn -q -DskipTests package && cp target/*.jar app.jar

ENV JAVA_TOOL_OPTIONS="-XX:InitialRAMPercentage=40 -XX:MaxRAMPercentage=75 -Djava.security.egd=file:/dev/./urandom"
EXPOSE 9090
ENTRYPOINT ["java","-jar","/app/app.jar"]
