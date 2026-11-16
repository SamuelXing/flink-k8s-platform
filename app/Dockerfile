# syntax=docker/dockerfile:1

# ---- build the runner jar ----------------------------------------------
# Only our own code is compiled here: every Flink dependency is `provided`,
# so the result is a few KB, not a 200 MB fat jar.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q clean package

# ---- runtime ------------------------------------------------------------
FROM flink:1.20.0-scala_2.12-java17

# The S3 filesystem ships inside the image but is not active until it is moved
# into plugins/. Without this, every s3:// checkpoint path fails at runtime.
RUN mkdir -p /opt/flink/plugins/s3-fs-presto && \
    cp /opt/flink/opt/flink-s3-fs-presto-*.jar /opt/flink/plugins/s3-fs-presto/

# Kafka: the plain connector plus kafka-clients, NOT flink-sql-connector-kafka.
# The SQL uber-jar relocates Kafka's classes under a shaded package, and the
# MSK IAM callback handler implements the un-relocated interface, so with the
# uber-jar IAM auth fails with a ClassCastException at connect time.
ARG MAVEN=https://repo1.maven.org/maven2
ARG KAFKA_CONNECTOR_VERSION=3.3.0-1.20
ARG KAFKA_CLIENTS_VERSION=3.4.0
ARG MSK_IAM_AUTH_VERSION=2.3.2
ADD --chmod=644 \
  ${MAVEN}/org/apache/flink/flink-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar \
  /opt/flink/lib/flink-connector-kafka.jar
ADD --chmod=644 \
  ${MAVEN}/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}/kafka-clients-${KAFKA_CLIENTS_VERSION}.jar \
  /opt/flink/lib/kafka-clients.jar
# Only used when kafka.iamAuth is on (MSK). Harmless otherwise.
ADD --chmod=644 \
  ${MAVEN}/software/amazon/msk/aws-msk-iam-auth/${MSK_IAM_AUTH_VERSION}/aws-msk-iam-auth-${MSK_IAM_AUTH_VERSION}-all.jar \
  /opt/flink/lib/aws-msk-iam-auth.jar

COPY --from=build /build/target/flink-sql-runner.jar /opt/flink/usrlib/flink-sql-runner.jar

# No SQL in the image on purpose: it arrives as a mounted ConfigMap, so a
# pipeline change is a config change and not a rebuild.
