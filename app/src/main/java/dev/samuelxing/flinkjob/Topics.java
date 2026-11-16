package dev.samuelxing.flinkjob;

import org.apache.kafka.clients.admin.Admin;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.admin.TopicDescription;
import org.apache.kafka.common.errors.TopicExistsException;
import org.apache.kafka.common.errors.UnknownTopicOrPartitionException;

import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

/**
 * Creates topics that do not exist yet, with an explicit partition count.
 *
 *   Topics <bootstrap> <name>:<partitions>:<replication> [...]
 *
 * It exists because auto-creation is off everywhere in this repo and something
 * has to create topics on MSK, where there is no Strimzi topic operator. It
 * ships in the job image so that it runs with the same client libraries, the
 * same IAM role and the same network path as the jobs themselves.
 *
 * It never changes an existing topic. A partition count that differs from the
 * one asked for is reported and left alone: adding partitions changes which
 * partition every key lands in, and that is not a decision for a deploy step.
 */
public final class Topics {

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            throw new IllegalArgumentException(
                    "usage: Topics <bootstrap> <name>:<partitions>:<replication> [...]");
        }
        Properties props = new Properties();
        props.put("bootstrap.servers", args[0]);
        props.put("request.timeout.ms", "30000");
        if ("true".equalsIgnoreCase(System.getenv("KAFKA_IAM_AUTH"))) {
            props.put("security.protocol", "SASL_SSL");
            props.put("sasl.mechanism", "AWS_MSK_IAM");
            props.put("sasl.jaas.config",
                    "software.amazon.msk.auth.iam.IAMLoginModule required;");
            props.put("sasl.client.callback.handler.class",
                    "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        }

        boolean mismatch = false;
        try (Admin admin = Admin.create(props)) {
            for (int i = 1; i < args.length; i++) {
                String[] spec = args[i].split(":");
                if (spec.length != 3) {
                    throw new IllegalArgumentException(
                            "expected <name>:<partitions>:<replication>, got: " + args[i]);
                }
                String name = spec[0];
                int partitions = Integer.parseInt(spec[1]);
                short replication = Short.parseShort(spec[2]);

                Integer existing = partitionCount(admin, name);
                if (existing == null) {
                    try {
                        admin.createTopics(Collections.singleton(
                                new NewTopic(name, partitions, replication))).all().get();
                        System.out.printf("created  %s  partitions=%d replication=%d%n",
                                name, partitions, replication);
                    } catch (ExecutionException e) {
                        if (!(e.getCause() instanceof TopicExistsException)) {
                            throw e;
                        }
                        System.out.printf("exists   %s  (created concurrently)%n", name);
                    }
                } else if (existing == partitions) {
                    System.out.printf("exists   %s  partitions=%d%n", name, existing);
                } else {
                    mismatch = true;
                    System.out.printf("MISMATCH %s  has %d partitions, wanted %d: left as is%n",
                            name, existing, partitions);
                }
            }
        }
        if (mismatch) {
            System.exit(2);
        }
    }

    private static Integer partitionCount(Admin admin, String name) throws Exception {
        try {
            TopicDescription d = admin.describeTopics(Collections.singleton(name))
                    .allTopicNames().get().get(name);
            return d.partitions().size();
        } catch (ExecutionException e) {
            if (e.getCause() instanceof UnknownTopicOrPartitionException) {
                return null;
            }
            throw e;
        }
    }

    private Topics() {
    }
}
