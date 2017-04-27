# -*- coding: UTF-8 -*-
require "spec_helper"
require 'fileutils'

RSpec.describe CartonDb::Escaping do

  let(:input) {
    input =
        (0..127).to_a.pack('U*') \
      + " Escaping's \"Hello!\""
  }

  it "produces escaped text without any raw control characters" do
    esc = subject.escape(input)
    expect( esc ).not_to match( /[\u0001-\u001F\u007F]/ )
  end

  it "reproduces original text when unescaping" do
    esc = subject.escape(input)
    unesc = subject.unescape(esc)
    expect( unesc ).to eq( input )
  end
end
