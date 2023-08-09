# frozen_string_literal: true

RSpec.describe AvroTurf::GlueMessaging do
  let(:avro) do
    AvroTurf::GlueMessaging.new(
      registry_name: "registry-name",
      schemas_path: "spec/schemas",
      client: Aws::Glue::Client.new(stub_responses: true)
    )
  end
  let(:stub_client) { avro.client }

  let(:address_schema_name) { "address" }
  let(:person_schema_name) { "person" }
  let(:person_list_schema_name) { "person_list" }

  let(:address) { {"street" => "55 University Ave", "city" => "Toronto"} }
  let(:person1) { {"full_name" => "John Doe", "address" => address} }
  let(:person2) { {"full_name" => "Jane Doe", "address" => address} }

  it "encodes and decodes messages" do
    stub_client.stub_responses(
      :get_schema_by_definition,
      schema_version_id: "12345678-1234-5678-1234-567812345678"
    )
    stub_client.stub_responses(
      :get_schema_version,
      schema_definition: File.read(File.join("spec/schemas", address_schema_name + ".avsc"))
    )

    data = avro.encode(address, schema_name: address_schema_name)
    expect(avro.decode(data)).to eq(address)
  end

  it "raises ValidationError if message is invalid" do
    expect do
      avro.encode({"city" => "Toronto"}, schema_name: address_schema_name)
    end.to raise_error(Avro::SchemaValidator::ValidationError)
  end

  it "passes the fully parsed schema definition for inter-schema references" do
    fully_parsed_schema_definition =
      Avro::Schema.parse(
        File.read(File.join("spec/schemas/full", person_schema_name + ".avsc"))
      ).to_s

    stub_client.stub_responses(
      :get_schema_version,
      schema_definition: fully_parsed_schema_definition
    )
    expect(stub_client).to receive(:get_schema_by_definition).with(
      {
        schema_id: {
          schema_name: person_schema_name,
          registry_name: "registry-name"
        },
        schema_definition: fully_parsed_schema_definition
      }
    ).and_return(
      Aws::Glue::Types::GetSchemaByDefinitionResponse.new(
        schema_version_id: "12345678-1234-5678-1234-567812345678"
      )
    )

    data = avro.encode(person1, schema_name: person_schema_name)
    expect(avro.decode(data)).to eq(person1)
  end

  it "passes the fully parsed schema definition for arrays" do
    fully_parsed_schema_definition =
      Avro::Schema.parse(
        File.read(File.join("spec/schemas/full", person_list_schema_name + ".avsc"))
      ).to_s

    stub_client.stub_responses(
      :get_schema_version,
      schema_definition: fully_parsed_schema_definition
    )
    expect(stub_client).to receive(:get_schema_by_definition).with(
      {
        schema_id: {
          schema_name: person_list_schema_name,
          registry_name: "registry-name"
        },
        schema_definition: fully_parsed_schema_definition
      }
    ).and_return(
      Aws::Glue::Types::GetSchemaByDefinitionResponse.new(
        schema_version_id: "12345678-1234-5678-1234-567812345678"
      )
    )

    data = avro.encode([person1, person2], schema_name: person_list_schema_name)
    expect(avro.decode(data)).to eq([person1, person2])
  end
end
