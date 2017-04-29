# -*- coding: UTF-8 -*-
require "spec_helper"
require 'fileutils'

RSpec.describe CartonDb::ListMapDb do

  before do
    destroy_workspace
    ensure_workspace_exists
  end

  subject {
    described_class.new(full_db_name)
  }

  def ensure_workspace_exists
    FileUtils.mkpath workspace_dir
  end

  def destroy_workspace
    FileUtils.rm_rf workspace_dir
  end

  let(:workspace_dir) {
    File.join(TEMP_DIR, 'list_map_spec')
  }

  let(:full_db_name) {
    File.join(workspace_dir, 'the_database')
  }

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

  it "can contain many distinct entries", slow: true do
    begin
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
    ensure
      # Slow operation. Be slow here so next supposedly non-slow
      # test doesn't have to wait for it.
      destroy_workspace
    end
  end

  it "is initially empty" do
    expect( subject ).to be_empty
  end

  it "is not empty after an entry has been created" do
    subject.append_to('the key', 'first element')
    expect( subject ).not_to be_empty
  end

  it "initially has a count of 0" do
    expect( subject.count ).to be_zero
  end

  it "has its number of key/array entries as its count when entries exist" do
    subject['a'] = %w(a)
    subject['b'] = %w(a b)
    subject['c'] = %w(a b c)

    expect( subject.count ).to eq( 3 )
  end

  it "is empty and has a count of 0 after being cleared when already empty" do
    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "is empty and has a count of 0 after being cleared when it has entries" do
    subject['key a'] = ['entry a1']
    subject['key b'] = ['entry b1', 'entry b2']

    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "supports all kinds of characters in key and array element strings" do
    key = "\\\u0000\u0005\n\t\u007F'\"⋍"
    value = ["\\", "\u0000", "\u007F", "\\", "'", '"', '\n\t⋍']

    subject[key] = value
    expect( subject[key] ).to eq( value )
  end

  it "enumerates its key/array entries" do
    subject['key a'] = ['entry a1']
    subject['key b'] = ['entry b1', 'entry b2']
    subject['key c'] = []

    entries = subject.to_enum(:each).to_a

    expect( entries ).to contain_exactly(
      [ 'key a', ['entry a1'] ],
      [ 'key b', ['entry b1', 'entry b2'] ],
      [ 'key c', [] ],
    )
  end

end
