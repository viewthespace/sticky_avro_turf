# frozen_string_literal: true

require "avro_turf"
require "avro_turf/glue_schema_registry"

class AvroTurf
  class GlueMessaging
    MAGIC_BYTE = [3].pack("C").freeze
    COMPRESSION_ENABLED_BYTE = [5].pack("C").freeze
    COMPRESSION_DISABLED_BYTE = [0].pack("C").freeze

    class DecodedMessage
      attr_reader :schema_id, :message

      def initialize(schema_id, message)
        @schema_id = schema_id
        @message = message
      end
    end

    attr_reader :schema_store
    attr_reader :client
    attr_reader :registry
    attr_accessor :schemas_by_id

    # Instantiate a new Messaging instance with the given configuration.
    #
    # schema_store         - A schema store object that responds to #find(schema_name, namespace).
    # schemas_path         - The String file system path where local schemas are stored.
    # registry_name
    # client
    def initialize(
      registry_name: nil,
      schema_store: nil,
      schemas_path: nil,
      client: Aws::Glue::Client.new
    )
      @schema_store = schema_store || SchemaStore.new(path: schemas_path || DEFAULT_SCHEMAS_PATH)
      @client = client
      @registry =
        AvroTurf::GlueSchemaRegistry.new(
          registry_name: registry_name,
          client: client
        )
      @schemas_by_id = {}
    end

    # Encodes a message using the specified schema.
    #
    # message     - The message that should be encoded. Must be compatible with
    #               the schema.
    # schema_name - The String name of the schema that should be used to encode
    #               the data.
    # schema_id   - The integer id of the schema that should be used to encode
    #               the data.
    # validate    - The boolean for performing complete message validation before
    #               encoding it, Avro::SchemaValidator::ValidationError with
    #               a descriptive message will be raised in case of invalid message.
    #
    # Returns the encoded data as a String.
    def encode(message, schema_name: nil, schema_id: nil, validate: true)
      writers_schema = schema_store.find(schema_name)
      schema, schema_id =
        if schema_id
          fetch_schema_by_id(schema_id)
        elsif schema_name && writers_schema
          fetch_schema_by_definition(writers_schema, schema_name)
        else
          raise ArgumentError.new(
            "Neither schema_name nor schema_id nor schema_name + schema definition provided to determine the schema."
          )
        end

      if validate
        Avro::SchemaValidator.validate!(
          schema,
          message,
          recursive: true,
          encoded: false,
          fail_on_extra_fields: true
        )
      end

      encode_message(message, schema, schema_id)
    end

    def encode_message(message, schema, schema_id)
      stream = StringIO.new
      writer = Avro::IO::DatumWriter.new(schema)
      encoder = Avro::IO::BinaryEncoder.new(stream)

      # Always start with the magic byte.
      encoder.write(MAGIC_BYTE)

      # Don't compress payload for now.
      encoder.write(COMPRESSION_DISABLED_BYTE)

      # The schema id is encoded as a 32-bit hex string.
      encoder.write([schema_id.delete("-")].pack("H*"))

      # The actual message comes last.
      writer.write(message, encoder)

      stream.string
    end

    # Decodes data into the original message.
    #
    # data        - A String containing encoded data.
    #
    # Returns the decoded message.
    def decode(data)
      decode_message(data).message
    end

    # Decodes data into the original message.
    #
    # data        - A String containing encoded data.
    #
    # Returns Struct with the next attributes:
    #   schema_id  - The integer id of schema used to encode the message
    #   message    - The decoded message
    def decode_message(data)
      stream = StringIO.new(data)
      decoder = Avro::IO::BinaryDecoder.new(stream)

      # The first byte is MAGIC!!!
      magic_byte = decoder.read(1)

      if magic_byte != MAGIC_BYTE
        raise "Expected data to begin with a magic byte, got `#{magic_byte.inspect}`"
      end

      compression_byte = decoder.read(1)

      # The schema id is a 32-bit hex string.
      schema_id =
        decoder.read(16).unpack1("H*").sub(/(.{8})(.{4})(.{4})(.{4})(.{12})/, '\1-\2-\3-\4-\5')

      writers_schema =
        schemas_by_id.fetch(schema_id) do
          schema, schema_id = fetch_schema_by_id(schema_id)
          schemas_by_id[schema_id] = schema
        end

      reader = Avro::IO::DatumReader.new(writers_schema, nil)
      message = reader.read(decoder)

      if compression_byte == COMPRESSION_ENABLED_BYTE
        p "Do some decompression here"
      elsif compression_byte != COMPRESSION_DISABLED_BYTE
        raise "Compression byte is not recognized, got `#{compression_byte.inspect}`"
      end

      DecodedMessage.new(schema_id, message)
    end

    # Fetch the schema from registry with the provided schema_id.
    def fetch_schema_by_id(schema_id)
      schema =
        schemas_by_id.fetch(schema_id) do
          schema_json = registry.fetch(schema_id)
          Avro::Schema.parse(schema_json)
        end
      [schema, schema_id]
    end

    def fetch_schema_by_definition(schema, subject)
      schema_id = registry.fetch_by_definition(subject, schema)
      [schema, schema_id]
    end

    # Schemas are registered under the full name of the top level Avro record
    # type, or `subject` if it's provided.
    def register_schema(schema_name:, subject: nil)
      registry.register(schema_name, subject)
    end
  end
end
