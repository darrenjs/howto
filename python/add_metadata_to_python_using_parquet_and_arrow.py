# Example of saving metadata & DataFrame together in a Parquet file.
#

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import json

# example data
df = pd.DataFrame(
  { 'temp': [12.1, 11, 13, 10, 10],
    'rain': [9.2, 10.0, 2.2, 0.2, 0.4] },
    index=pd.DatetimeIndex(['2020-10-12',
                            '2020-10-13',
                            '2020-10-14',
                            '2020-10-15',
                            '2020-10-16'],
                           name='date')
)

# example metadata, and our custom key at which it will be stored.
custom_meta_key = 'weatherapp.iot'
custom_meta_content = {
    'user': 'Wáng Fāng',
    'coord': '55.9533° N, 3.1883° W',
    'time': '2020-10-17T03:59:59+0000'  # ISO-8601
}


# convert DataFrame to Arrow table
table = pa.Table.from_pandas(df)

# show the table meta data
print(table.schema.metadata)

# decode the Arrow metadata into a plain nested dict, and print
pandas_meta = json.loads(table.schema.metadata[b'pandas'])
print(pandas_meta)

# Arrow metadata can only be byte strings, so we must encode our metadata into
# such a format (we will also do the same for custom_meta_key). This returns a
# pure ASCII string, which means UTF characters will be appear like: \u0103
custom_meta_json = json.dumps(custom_meta_content)

# Build the new global metadata by merging together our custom metadata and the
# existing metadata; it is because of this merge that we need to choose a unique
# namespace key for our custom metadata.
existing_meta = table.schema.metadata
combined_meta = {
    custom_meta_key.encode() : custom_meta_json.encode(),
    **existing_meta
}

# Create a new Arrow table by copying existing table but with the metadata
# replaced.  Store the new table in the reused `table` variable.
table = table.replace_schema_metadata(combined_meta)

# write the file
pq.write_table(table, 'example.parquet', compression='GZIP')

# now load it back in
restored_table = pq.read_table('example.parquet')

# obtain the orignal DataFrame
restored_df = restored_table.to_pandas()

# to get our custom metadata, we first retrieve from the global namespace
restored_meta_json = restored_table.schema.metadata[custom_meta_key.encode()]

# since we stored as an encoded string, we need to decode it
restored_meta = json.loads(restored_meta_json)
