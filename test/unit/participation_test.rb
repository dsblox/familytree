require 'test_helper'

class ParticipationTest < ActiveSupport::TestCase
  test "create a basic participation object" do
    part = Participation.new(:person => nil, :event => nil, :role => :child)
    assert part != nil
  end
end
