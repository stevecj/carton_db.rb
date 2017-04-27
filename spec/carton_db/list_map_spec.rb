# -*- coding: UTF-8 -*-
require "spec_helper"
require 'fileutils'

RSpec.describe CartonDb::ListMap do
  before do
    FileUtils.rm_rf workspace_dir
    FileUtils.mkpath workspace_dir
  end

  subject {
    described_class.new(full_db_name)
  }

  let(:workspace_dir) {
    File.join(TEMP_DIR, 'list_map_spec')
  }

  let(:full_db_name) {
    File.join(workspace_dir, 'the_database')
  }

  it "is initially empty" do
    expect( subject ).to be_empty
  end

  it "initially finds a nil value for any key" do
    expect( subject['anything'] ).to be_nil
  end

  it "creates an empty array by value assignment" do
    subject['the key'] = []
    expect( subject['the key'] ).to eq( [] )
  end

  it "creates a populated array by value assignment" do
    subject['the key'] = ['element a', 'element b']
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "overwrites an existing array by value assignment" do
    subject['the key'] = ['element a', 'element b']

    subject['the key'] = []
    expect( subject['the key'] ).to eq( [] )

    subject['the key'] = ['one', 'two', 'three']
    expect( subject['the key'] ).to eq( ['one', 'two', 'three'] )
  end

  it "deletes an existing empty-array entry" do
    subject['the key'] = []
    subject.delete 'the key'
    expect( subject['the key'] ).to be_nil
  end

  it "deletes an existing populated empty-array entry" do
    subject['the key'] = ['element a', 'element b']
    subject.delete 'the key'
    expect( subject['the key'] ).to be_nil
  end

  it "creates an array when appending to a non-existent array" do
    subject.append_to('the key', 'first element')
    expect( subject['the key'] ).to eq( ['first element'] )
  end

  it "creates an empty array when concatenating an empty collection to a non-existent array" do
    subject.concat_to('the key', [])
    expect( subject['the key'] ).to eq( [] )
  end

  it "creates a populated array when concatenating a populated collection to a non-existent array" do
    subject.concat_to('the key', ['element a', 'element b'])
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "is not empty after an array entry has been created" do
    subject.append_to('the key', 'first element')
    expect( subject ).not_to be_empty
  end

  it "supports all kinds of characters in keys and values" do
    key = "\\\u0000\u0005\n\u007F'\"⋍"
    value = ["\\", "\u0000", "\u007F", "\\", "'", '"', '\n\t⋍']

    subject[key] = value
    expect( subject[key] ).to eq( value )
  end

  it "manages many distinct entries", slow: true do
    # The current implementation has up to 128 directories, each
    # containing up to 128 files.  Creating more than 16,384
    # entries ensures that some of the files must store data for
    # for multiple entries each.
    entries = (0...18_000).map { |n|
      element_count = n % 50
      key = n.to_s
      array_val = (0...element_count).map(&:to_s)
      [key, array_val]
    }
    entries.each do |key, array_val|
      subject[key] = array_val
    end
    entries.each do |key, array_val|
      expect( subject[key] ).to eq( array_val )
    end
  end
end
