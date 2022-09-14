# frozen_string_literal: true

RSpec.describe AvroTurf::GlueMessaging do
  let(:avro) do
    AvroTurf::GlueMessaging.new(
      registry_name: 'registry-name',
      access_key_id: 'test-access-key',
      secret_access_key: 'test-secret',
      session_token: 'test-token',
      region: 'us-east-1',
      schemas_path: 'spec/schemas',
    )
  end
  let(:message) { { 'full_name' => 'John Doe' } }
  let(:schema_name) { 'person' }
  let(:schema_json) { <<-AVSC }
      {
        "name": "person",
        "type": "record",
        "fields": [
          {
            "type": "string",
            "name": "full_name"
          }
        ]
      }
    AVSC
  let(:schema) { Avro::Schema.parse(schema_json) }

  before do
    FileUtils.mkdir_p('spec/schemas')
    File.write(File.join('spec/schemas', 'person.avsc'), schema_json)
  end

  before do
    allow_any_instance_of(AvroTurf::GlueSchemaRegistry).to receive(:fetch_by_definition).and_return(
      '12345678-1234-5678-1234-567812345678',
    )
    allow_any_instance_of(AvroTurf::GlueSchemaRegistry).to receive(:fetch).and_return(schema_json)
  end

  after { FileUtils.remove_dir('spec/schemas') }

  it 'encodes and decodes messages' do
    data = avro.encode(message, schema_name: schema_name)
    expect(avro.decode(data)).to eq message
  end

  it 'raises ValidationError if message is invalid' do
    expect do avro.encode({ 'name' => 'John Doe' }, schema_name: schema_name) end.to raise_error(
      Avro::SchemaValidator::ValidationError,
    )
  end
end
