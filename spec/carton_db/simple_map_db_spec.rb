# -*- coding: UTF-8 -*-
require "spec_helper"
require 'fileutils'

RSpec.describe CartonDb::SimpleMapDb do

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

  it "creates a nil entry by assignment" do
    subject['the key'] = nil
    expect( subject.key?('the key') ).to eq( true )
    expect( subject['the key'] ).to be_nil
  end

  it "creates a string-valued entry by assignment" do
    subject['the key'] = 'the value'
    expect( subject['the key'] ).to eq( 'the value' )
  end

  it "is empty when no entries have been added" do
    expect( subject ).to be_empty
  end

  it "is not empty when an entry has been added" do
    subject['the key'] = 'a value'
    expect( subject ).not_to be_empty
  end

  it "initially has a count of 0" do
    expect( subject.count ).to be_zero
  end

  it "has its number of entries (keys) as its count when entries exist" do
    subject['a'] = '1'
    subject['b'] = '2'
    subject['c'] = nil

    expect( subject.count ).to eq( 3 )
  end

  it "overwrites an existing entry by assignment" do
    subject['the key'] = 'original'
    subject['the key'] = 'new'
    expect( subject['the key'] ).to eq( 'new' )
  end

  it "deletes an existing entry" do
    subject['the key'] = 'the value'
    subject.delete 'the key'
    expect( subject.key?('the key') ).to eq( false )
  end

  [:small, :fast].each do |optimization|
    context "using #{optimization} optimization" do
      it "creates a nil entry when a key is touched" do
        subject.touch 'the key', optimization: optimization
        expect( subject['the key'] ).to eq( nil )
      end

      it "leaves an existing entry's value unchanged when its key is touched" do
        subject['the key'] = 'the value'
        subject.touch 'the key', optimization: optimization
        expect( subject['the key'] ).to eq( 'the value' )
      end
    end
  end

  it "indicates that it does not have a key when none of its entries has that key" do
    subject['key a'] = 'abc'
    expect( subject.key?('key b') ).to eq( false )
  end

  it "indicates that it has a key when one of its entries has that key" do
    subject['key a'] = 'abc'
    subject['key b'] = nil
    expect( subject.key?('key a') ).to eq( true )
    expect( subject.key?('key b') ).to eq( true )
  end

  it "is empty and has a count of 0 after being cleared when already empty" do
    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "is empty and has a count of 0 after being cleared when it had entries" do
    subject['key a'] = '1'
    subject['key b'] = '2'

    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "enumerates its entries" do
    subject['key a'] = 'entry a'
    subject['key b'] = 'entry b'
    subject['key c'] = nil

    entries = subject.to_enum(:each).to_a

    expect( entries ).to contain_exactly(
      [ 'key a', 'entry a' ],
      [ 'key b', 'entry b' ],
      [ 'key c', nil ],
    )
  end

end
