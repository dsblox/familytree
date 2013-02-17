require 'test_helper'

class PersonTest < ActiveSupport::TestCase
  test "can_create_simple_person" do
    david = Person.new( :firstName => "David", :lastName => "Block", :gender => Gender::MALE)
    assert david.save, "unable to create a simple object"
  end
  
  test "set birthdate on a person" do
    david = Person.new( :firstName => "David", :lastName => "Block", :gender => Gender::MALE)
    david.birth(Date.new(1965,4,16))
    result = david.save
    assert result, "unable to save person with a birthdate: #{result}"
  end
end
