# Sticky AvroTurf

Sticky AvroTurf is a ruby library that provides serialization and deserialization of messages using Apache Avro schemas stored in the AWS Glue Schema Registry.

This library:

- handles the client connection to AWS Glue
- registers the schema definition to the AWS Glue Schema Registry (TODO)
- validates the message against its schema
- serializes/deserializes messages with the appropriate schema version information retrieved from the AWS Glue Schema Registry

This library is meant to be used by both the producer and consumer for handling serialization and deserialization.

## Assumptions

- A Schema Registry has already been provisioned on AWS Glue
- Schema definition files are hosted locally with the producer application
- Schemas in the registry are named according to the schema file name, without the extension
- It only works with Avro schemas. AWS Glue Schema Registry also supports JSON and Protobuf schemas

## Usage

Sticky AvroTurf follows the [`AvroTurf::Messaging` API](https://github.com/dasch/avro_turf/blob/master/README.md#using-a-schema-registry) closely.

```ruby
require 'sticky_avro_turf'

# TODO: Use role credentials instead of access keys and tokens
avro = AvroTurf:GlueMessaging.new(
  registry_name: 'registry-name',
  access_key_id: 'test-access-key',
  secret_access_key: 'test-secret',
  session_token: 'test-token',
  region: 'us-east-1',
  schemas_path: 'spec/schemas',
)

# This method serializes the message with the schema version id
# TODO: If the schema is not yet registered in the registry, then it will be
# automatically registered with the schema_name
data = avro.encode({ 'full_name' => 'John Doe' }, schema_name: 'person')

# The schema can also be identified by its schema version id, assuming the
# schema has already been registered
schema_id = '12345678-abcd-ef12-3456-78abcdef1234'
data = avro.encode({ 'full_name' => 'John Doe' }, schema_id: schema_id)

# Validation can be turned off
data = avro.encode({ 'full_name' => 'John Doe' }, schema_name: 'person', validate: false)

avro.decode(data) #=> { 'full_name' => 'John Doe' }
```

## References

This library is based on work from the following libraries:

[AWS Glue Schema Registry Library](https://github.com/awslabs/aws-glue-schema-registry) (Officially provided by AWS)

[AWS Glue Schema Registry for Python](https://github.com/DisasterAWARE/aws-glue-schema-registry-python)

[AvroTurf](https://github.com/dasch/avro_turf)
