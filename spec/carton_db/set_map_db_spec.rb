# -*- coding: UTF-8 -*-
require "spec_helper"
require 'fileutils'
require 'set'

RSpec.describe CartonDb::SetMapDb do

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

  it "creates an empty set entry by value assignment" do
    subject['the key'] = Set.new
    expect( subject['the key'] ).to eq( Set.new )
  end

  it "creates a populated list entry by value assignment" do
    subject['the key'] = Set.new(['elem a', 'elem b'])
    expect( subject['the key'] ).to eq( Set.new(['elem a', 'elem b']) )
  end

  it "is empty when no entries have been added" do
    expect( subject ).to be_empty
  end

  it "is not empty when an entry has been added" do
    subject['the key'] = Set.new( ['an element'] )
    expect( subject ).not_to be_empty
  end

  it "overwrites an existing entry by value assignment" do
    subject['the key'] = Set.new( ['elem a', 'elem b'] )

    subject['the key'] = Set.new
    expect( subject['the key'] ).to eq( Set.new )

    subject['the key'] = Set.new( ['one', 'two', 'three'] )
    expect( subject['the key'] ).
      to eq( Set.new(['one', 'two', 'three']) )
  end

  it "deletes an existing empty-set entry" do
    subject['the key'] = Set.new
    subject.delete 'the key'
    expect( subject['the key'] ).to be_nil
  end

  it "deletes an existing populated set entry" do
    subject['the key'] = Set.new( ['elem a', 'elem b'] )
    subject.delete 'the key'
    expect( subject['the key'] ).to be_nil
  end

  it "creates a populated entry when an element of a non-existent entry is touched" do
    subject.touch_element 'the key', 'the element'
    expect( subject['the key'] ).to eq( Set.new(['the element']) )
  end

  it "adds an element when a non-existent entry element is touched" do
    subject['the key'] = Set.new( ['elem a', 'elem b'] )
    subject.touch_element 'the key', 'elem c'
    expect( subject['the key'] ).
      to eq( Set.new(['elem a', 'elem b', 'elem c']) )
  end

  it "has no effect when a an existing entry element is touched" do
    subject['the key'] = Set.new( ['elem a', 'elem b'] )
    subject.touch_element 'the key', 'elem b'
    expect( subject['the key'] ).to eq( Set.new(['elem a', 'elem b']) )
  end

  it "creates an empty entry when an empty elements collection is merged to a non-existent entry" do
    subject.merge_elements 'the key', Set.new
    expect( subject['the key'] ).to eq( Set.new )
  end

  it "creates a populated entry when elements are merged to an non-existent entry" do
    subject.merge_elements 'the key', Set.new( ['elem a', 'elem b'] )
    expect( subject['the key'] ).to eq( Set.new(['elem a', 'elem b']) )
  end

  it "adds to an entry when new elements are merged to an existing entry" do
    subject['the key'] = Set.new( ['a'] )
    subject.merge_elements 'the key', Set.new( ['b', 'c'] )
    expect( subject['the key'] ).
      to eq( Set.new(['a', 'b', 'c']) )
  end

  it "has no effect when merging existing elements to an entry" do
    subject['the key'] = Set.new( ['a', 'b', 'c'] )
    subject.merge_elements 'the key', Set.new( ['b', 'c'] )
    expect( subject['the key'] ).to eq( Set.new(['a', 'b', 'c']) )
  end

  it "adds additional elements when merging to an entry" do
    subject['the key'] = Set.new( ['a', 'b', 'c'] )
    subject.merge_elements 'the key', Set.new( ['b', 'c', 'd'] )
    expect( subject['the key'] ).
      to eq( Set.new(['a', 'b', 'c', 'd']) )
  end

  it "recognizes the non-existence of an entry element with a given value" do
    subject['some key'] = Set.new( ['elem a', 'elem b'] )
    expect( subject.element?('another key', 'elem a') ).
      to eq( false )
    expect( subject.element?('some key', 'elem c') ).
      to eq( false )
  end

  it "recognizes the existence of an entry element with a given value" do
    subject['some key'] = Set.new( ['elem a', 'elem b'] )
    expect( subject.element?('some key', 'elem b') ).
      to eq( true )
  end

  it "is initially empty" do
    expect( subject ).to be_empty
  end

  it "is not empty after an entry has been created" do
    subject['the key'] = Set.new( ['an element'] )
    expect( subject ).not_to be_empty
  end

  it "initially has a count of 0" do
    expect( subject.count ).to be_zero
  end

  it "has its number of entries (keys) as its count when entries exist" do
    subject['a'] = Set.new( %w(a) )
    subject['b'] = Set.new( %w(a b) )
    subject['c'] = Set.new( %w(a b c) )

    expect( subject.count ).to eq( 3 )
  end

  [:small, :fast].each do |optimization|
    context "using #{optimization} optimization" do
      it "creates an empty array entry when a key is touched" do
        subject.touch 'the key', optimization: optimization
        expect( subject['the key'] ).to eq( Set.new )
      end

      it "leaves an existing entry's content unchanged when its key is touched" do
        subject['the key'] = Set.new( %w(a b) )
        subject.touch 'the key', optimization: optimization
        expect( subject['the key'] ).to eq( Set.new(%w(a b)) )
      end
    end
  end

  it "indicates that it does not have a key when none of its entries has that key" do
    subject['key a'] = Set.new( ['abc'] )
    expect( subject.key?('key b') ).to eq( false )
  end

  it "indicates that it has a key when one of its entries has that key" do
    subject['key a'] = Set.new( ['abc'] )
    subject['key b'] = Set.new
    expect( subject.key?('key a') ).to eq( true )
    expect( subject.key?('key b') ).to eq( true )
  end

  it "is empty and has a count of 0 after being cleared when already empty" do
    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "is empty and has a count of 0 after being cleared when it had entries" do
    subject['key a'] = Set.new( ['elem a1'] )
    subject['key b'] = Set.new( ['elem b1', 'elem b2'] )

    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "enumerates its entries" do
    subject['key a'] = Set.new( ['elem a1'] )
    subject['key b'] = Set.new( ['elem b1', 'elem b2'] )
    subject['key c'] = Set.new

    entries = subject.to_enum(:each).to_a

    expect( entries.count ).to eq( 3 )
    expect( entries ).to include( [ 'key a', Set.new(['elem a1']) ] )
    expect( entries ).to include( [ 'key b', Set.new(['elem b1', 'elem b2']) ] )
    expect( entries ).to include( [ 'key c', Set.new ] )
  end

end
