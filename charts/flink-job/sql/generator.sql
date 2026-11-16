-- Stands in for the upstream system: writes a synthetic order stream to Kafka.
-- In a real deployment this job does not exist and `orders` is produced by
-- whatever actually takes orders.
--
-- Rendered by Helm at install time: the bootstrap server and topic names
-- come from values.yaml, so this file is the same on a laptop and on EKS.

SET 'pipeline.name' = '{{ .Release.Name }}-generator';

CREATE TABLE gen (
  seq        BIGINT,
  cat_idx    INT,
  amount     DECIMAL(10,2),
  event_time TIMESTAMP_LTZ(3)
) WITH (
  'connector'               = 'datagen',
  'rows-per-second'         = '{{ .Values.generator.rowsPerSecond }}',
  'fields.seq.kind'         = 'sequence',
  'fields.seq.start'        = '1',
  'fields.seq.end'          = '9223372036854775807',
  'fields.cat_idx.min'      = '0',
  'fields.cat_idx.max'      = '4',
  'fields.amount.min'       = '1.00',
  'fields.amount.max'       = '500.00',
  -- Each row's event_time lands up to 5 seconds in the past, so the stream is
  -- genuinely out of order and the watermark has something to do.
  'fields.event_time.max-past' = '5000'
);

CREATE TABLE orders (
  order_id    STRING,
  customer_id STRING,
  category    STRING,
  amount      DECIMAL(10,2),
  event_time  TIMESTAMP_LTZ(3)
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = '{{ .Values.kafka.topics.orders }}',
  'properties.bootstrap.servers' = '{{ .Values.kafka.bootstrap }}',
  'key.format'                   = 'raw',
  'key.fields'                   = 'order_id',
  'value.format'                 = 'json'
);

INSERT INTO orders
SELECT CONCAT('o-', CAST(seq AS STRING)),
       CONCAT('c-', CAST(MOD(seq, 200) AS STRING)),
       CASE cat_idx
         WHEN 0 THEN 'BOOKS'
         WHEN 1 THEN 'ELECTRONICS'
         WHEN 2 THEN 'HOME'
         WHEN 3 THEN 'GROCERY'
         ELSE        'TOYS'
       END,
       amount,
       event_time
FROM gen;
