import os
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("init-table").getOrCreate()

spark.conf.set(
    "spark.sql.catalog.iceberg.credential",
    f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}",
)

spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.raw_food")
spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.stg_food")

spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.raw_food.orders (
        order_id    INT          NOT NULL,
        customer_id INT          NOT NULL,
        amount      DECIMAL(10,2),
        status      STRING,
        created_at  DATE,
        _processing_timestamp TIMESTAMP
    ) USING iceberg PARTITIONED BY (created_at)
""")

spark.stop()
