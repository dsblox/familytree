require 'test_helper'

class EventTest < ActiveSupport::TestCase
  test "can create an event" do
    e = Event.new(:eventName => "test event", :startDate => Date.new(1900,1,1))
    assert e != nil
  end
end
