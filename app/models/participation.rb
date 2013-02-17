class Participation < ActiveRecord::Base
  belongs_to :person
  belongs_to :event
  attr_accessible :role, :event, :person, :event_id, :event_date
  attr_accessor :event_type, :event_date1
  attr_accessor :person1_full_name, :person2_full_name, :person1_id, :person2_id
  
  # this is a mess to get around a rails bug to tell it how to map my non-db attr to the date class
  composed_of :event_date,
              :class_name => 'Date', 
              :mapping => %w(Date to_s), 
              :constructor => Proc.new{ |item| item}, 
              :converter => Proc.new{ |item| item }
  
  # this can probably go away once I get the object working right so no nils go in
  def role_str
    if (role == nil)
      role_result = "participant"
    else
      role_result = role
    end
    role_result
  end
  
  # this can probably go away once I get the object working right so no nils go in
  def event_str
    if (event == nil)
      event_str = "unknown event"
    else
      event_str = event.to_s
    end
    event_str
  end
  
  # this can probably go away once I get the object working right so no nils go in
  def person_str
    if (person == nil)
      person_result = "unknown event"
    else
      person_result = person.to_s
    end
    person_result
  end
  
  def to_s_event
    role_str + " at " + event_str
  end
  
  def to_s
    person_str + " was " + to_s_event
  end
  
end
