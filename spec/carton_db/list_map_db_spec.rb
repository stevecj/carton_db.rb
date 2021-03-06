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

  it "creates an empty list entry by value assignment" do
    subject['the key'] = []
    expect( subject['the key'] ).to eq( [] )
  end

  it "creates a populated list entry by value assignment" do
    subject['the key'] = ['element a', 'element b']
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "is empty when no entries have been added" do
    expect( subject ).to be_empty
  end

  it "is not empty when an entry has been added" do
    subject['the key'] = ['an element']
    expect( subject ).not_to be_empty
  end

  it "overwrites an existing entry by value assignment" do
    subject['the key'] = ['element a', 'element b']

    subject['the key'] = []
    expect( subject['the key'] ).to eq( [] )

    subject['the key'] = ['one', 'two', 'three']
    expect( subject['the key'] ).to eq( ['one', 'two', 'three'] )
  end

  it "deletes an existing empty-list entry" do
    subject['the key'] = []
    subject.delete 'the key'
    expect( subject['the key'] ).to be_nil
  end

  it "deletes an existing populated list entry" do
    subject['the key'] = ['element a', 'element b']
    subject.delete 'the key'
    expect( subject['the key'] ).to be_nil
  end

  it "creates an entry when appending to a non-existent entry" do
    subject.append_element('the key', 'first element')
    expect( subject['the key'] ).to eq( ['first element'] )
  end

  it "creates an empty entry when concatenating an empty collection to a non-existent entry using concat_elements" do
    subject.concat_elements('the key', [])
    expect( subject['the key'] ).to eq( [] )
  end

  it "creates a populated entry when concatenating a populated collection to a non-existent entry using concat_elements" do
    subject.concat_elements 'the key', ['element a', 'element b']
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "doesn't create an entry when concatenating an empty collection to a non-existent entry using concat_any_elements" do
    subject.concat_any_elements 'the key', []
    expect( subject['the key'] ).to be_nil
  end

  it "creates a populated entry when concatenating a populated collection to a non-existent entry using concat_any_elements" do
    subject.concat_any_elements 'the key', ['element a', 'element b']
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end


  it "creates a populated entry when an element of a non-existent entry is touched" do
    subject.touch_element 'the key', 'the element'
    expect( subject['the key'] ).to eq( ['the element'] )
  end

  it "appends an element when a non-existent entry element is touched" do
    subject['the key'] = ['element a', 'element b']
    subject.touch_element 'the key', 'element c'
    expect( subject['the key'] ).
      to eq( ['element a', 'element b', 'element c'] )
  end

  it "has no effect when a an existing entry element is touched" do
    subject['the key'] = ['element a', 'element b']
    subject.touch_element 'the key', 'element b'
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "creates an empty entry when an empty elements collection is merged to a non-existent entry" do
    subject.merge_elements 'the key', []
    expect( subject['the key'] ).to eq( [] )
  end

  it "has no effect when an empty elements collection is merged to an existing entry" do
    subject['the key'] = ['element a', 'element b']
    subject.merge_elements 'the key', []
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "creates a populated entry when elements are merged to an non-existent entry" do
    subject.merge_elements 'the key', ['element a', 'element b']
    expect( subject['the key'] ).to eq( ['element a', 'element b'] )
  end

  it "concatenates to an entry when new elements are merged to an existing entry" do
    subject['the key'] = ['a']
    subject.merge_elements 'the key', ['b', 'b', 'c']
    expect( subject['the key'] ).
      to eq( ['a', 'b', 'b', 'c'] )
  end

  it "has no effect when merging existing elements to an entry" do
    subject['the key'] = ['a', 'b', 'b', 'c']
    subject.merge_elements 'the key', ['b', 'b', 'c']
    expect( subject['the key'] ).to eq( ['a', 'b', 'b', 'c'] )
  end

  it "appends additional elements when merging to an entry" do
    subject['the key'] = ['a', 'b', 'b', 'c']
    subject.merge_elements 'the key', ['b', 'b', 'b', 'c', 'd']
    expect( subject['the key'] ).to eq( ['a', 'b', 'b', 'c', 'b', 'd'] )
  end

  it "recognizes the non-existence of an entry element with a given value" do
    subject['some key'] = ['element a', 'element b']
    expect( subject.element?('another key', 'element a') ).
      to eq( false )
    expect( subject.element?('some key', 'element c') ).
      to eq( false )
  end

  it "recognizes the existence of an entry element with a given value" do
    subject['some key'] = ['element a', 'element b']
    expect( subject.element?('some key', 'element b') ).
      to eq( true )
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
        content = (0...element_count).map(&:to_s)
        [key, content]
      }
      entries.each do |key, content|
        subject[key] = content
      end
      entries.each do |key, content|
        expect( subject[key] ).to eq( content )
      end
    ensure
      # Slow operation. Be slow here so next supposedly non-slow
      # test doesn't have to wait for it.
      destroy_workspace
    end
  end

  it "initially has a count of 0" do
    expect( subject.count ).to be_zero
  end

  it "has its number of entries (keys) as its count when entries exist" do
    subject['a'] = %w(a)
    subject['b'] = %w(a b)
    subject['c'] = %w(a b c)

    expect( subject.count ).to eq( 3 )
  end

  [:small, :fast].each do |optimization|
    context "using #{optimization} optimization" do
      it "creates an empty array entry when a key is touched" do
        subject.touch 'the key', optimization: optimization
        expect( subject['the key'] ).to eq( [] )
      end

      it "leaves an existing entry's content unchanged when its key is touched" do
        subject['the key'] = ['a', 'b']
        subject.touch 'the key', optimization: optimization
        expect( subject['the key'] ).to eq( ['a', 'b'] )
      end
    end
  end

  it "indicates that it does not have a key when none of its entries has that key" do
    subject['key a'] = ['abc']
    expect( subject.key?('key b') ).to eq( false )
  end

  it "indicates that it has a key when one of its entries has that key" do
    subject['key a'] = ['abc']
    subject['key b'] = []
    expect( subject.key?('key a') ).to eq( true )
    expect( subject.key?('key b') ).to eq( true )
  end

  it "is empty and has a count of 0 after being cleared when already empty" do
    subject.clear

    expect( subject ).to be_empty
    expect( subject.count ).to be_zero
  end

  it "is empty and has a count of 0 after being cleared when it had entries" do
    subject['key a'] = ['element a1']
    subject['key b'] = ['element b1', 'element b2']

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

  it "enumerates its entries" do
    subject['key a'] = ['element a1']
    subject['key b'] = ['element b1', 'element b2']
    subject['key c'] = []

    entries = subject.to_enum(:each).to_a

    expect( entries ).to contain_exactly(
      [ 'key a', ['element a1'] ],
      [ 'key b', ['element b1', 'element b2'] ],
      [ 'key c', [] ],
    )
  end

  it "enumerates its entry first elements" do
    subject['key a'] = ['element a1']
    subject['key b'] = ['element b1', 'element b2']
    subject['key c'] = []

    entries = subject.to_enum(:each_first_element).to_a

    expect( entries ).to contain_exactly(
      [ 'key a', 'element a1' ],
      [ 'key b', 'element b1' ],
      [ 'key c', nil ],
    )
  end

end
