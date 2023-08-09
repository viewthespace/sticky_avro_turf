# frozen_string_literal: true

require "aws-sdk-glue"

class AvroTurf
  class GlueSchemaRegistry
    attr_reader :registry_name
    attr_reader :client

    def initialize(
      registry_name: nil,
      client: Aws::Glue::Client.new
    )
      @registry_name = registry_name
      @client = client
    end

    def fetch(id)
      res = client.get_schema_version({schema_version_id: id})
      res.schema_definition
    end

    def fetch_by_definition(schema_name, schema)
      res =
        client.get_schema_by_definition(
          {
            schema_id: {
              schema_name: schema_name,
              registry_name: registry_name
            },
            schema_definition: schema.to_s
          }
        )
      res.schema_version_id
    end

    def register(subject, schema)
      resp = client.create_schema(
        {
          registry_id: {
            registry_name: registry_name
          },
          schema_name: subject,
          data_format: "AVRO",
          compatibility: "BACKWARD",
          schema_definition: schema
        }
      )
      resp.schema_version_id
    end

    # Check if a schema exists. Returns nil if not found.
    def check(subject, schema)
      resp = client.get_schema({schema_id: {
        schema_name: subject,
        registry_name: registry_name
      }})
      resp.data
    end
  end
end
