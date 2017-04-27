require "spec_helper"

RSpec.describe CartonDb do
  it "has a version number" do
    expect(CartonDb::VERSION).not_to be nil
  end
end
