# frozen_string_literal: true

require 'aws-sdk-glue'

class AvroTurf
  class GlueSchemaRegistry
    def initialize(
      registry_name: nil,
      access_key_id: nil,
      secret_access_key: nil,
      session_token: nil,
      region: nil
    )
      @registry_name = registry_name
      @client =
        Aws::Glue::Client.new(
          {
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            session_token: session_token,
            region: region,
          },
        )
    end

    def fetch(id)
      res = @client.get_schema_version({ schema_version_id: id })
      res.schema_definition
    end

    def fetch_by_definition(schema_name, schema)
      res =
        @client.get_schema_by_definition(
          {
            schema_id: {
              schema_name: schema_name,
              registry_name: @registry_name,
            },
            schema_definition: schema.to_s,
          },
        )
      res.schema_version_id
    end

    def register(subject, schema)
      raise NotImplementedError
    end

    # Check if a schema exists. Returns nil if not found.
    def check(subject, schema)
      raise NotImplementedError
    end
  end
end
