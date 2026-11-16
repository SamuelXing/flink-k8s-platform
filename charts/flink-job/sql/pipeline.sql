-- Revenue per category, in 1-minute event-time windows.
--
-- This is the same query as the course lab, on purpose: the point of this repo
-- is that the query does not change between a laptop and EKS. Only the
-- bootstrap server and the checkpoint bucket do.
--
-- Rendered by Helm at install time: the bootstrap server and topic names
-- come from values.yaml, so this file is the same on a laptop and on EKS.

SET 'pipeline.name' = '{{ .Release.Name }}-pipeline';

CREATE TABLE orders (
  order_id    STRING,
  customer_id STRING,
  category    STRING,
  amount      DECIMAL(10,2),
  event_time  TIMESTAMP_LTZ(3),
  -- A watermark does not travel through Kafka, so the reader declares its own.
  WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = '{{ .Values.kafka.topics.orders }}',
  'properties.bootstrap.servers' = '{{ .Values.kafka.bootstrap }}',
  'properties.group.id'          = '{{ .Release.Name }}-pipeline',
  'scan.startup.mode'            = 'latest-offset',
  'format'                       = 'json'
);

CREATE TABLE revenue_1m (
  window_start TIMESTAMP(3),
  window_end   TIMESTAMP(3),
  category     STRING,
  orders       BIGINT,
  revenue      DECIMAL(38,2)
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = '{{ .Values.kafka.topics.revenue }}',
  'properties.bootstrap.servers' = '{{ .Values.kafka.bootstrap }}',
  'format'                       = 'json'
);

INSERT INTO revenue_1m
SELECT window_start, window_end, category,
       COUNT(*)    AS orders,
       SUM(amount) AS revenue
FROM TABLE(
  TUMBLE(TABLE orders, DESCRIPTOR(event_time), INTERVAL '1' MINUTE))
GROUP BY window_start, window_end, category;
