import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp
from pyspark.sql.types import StructType, StructField, IntegerType, DecimalType, StringType, DateType

spark = SparkSession.builder.appName("load-mock-data").getOrCreate()

spark.conf.set(
    "spark.sql.catalog.iceberg.credential",
    f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}",
)

schema = StructType([
    StructField("order_id",    IntegerType(), False),
    StructField("customer_id", IntegerType(), False),
    StructField("amount",      DecimalType(10, 2), True),
    StructField("status",      StringType(), True),
    StructField("created_at",  DateType(), True),
])

df = (
    spark.read
    .option("header", True)
    .schema(schema)
    .csv("/opt/spark/work-dir/orders.csv")
    .withColumn("_processing_timestamp", current_timestamp())
)

df.writeTo("iceberg.raw_food.orders").append()

print(f"Loaded {df.count()} rows into iceberg.raw_food.orders")
spark.stop()
