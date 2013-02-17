class Event < ActiveRecord::Base
  attr_accessible :endDate, :eventName, :startDate
  
  has_many :participations, :dependent => :destroy
  has_many :people, :through => :participations
  
  def to_s
    date_to_show = startDate.to_s
    if (date_to_show.blank?)
      date_to_show = "exact date unknown"
    end
    eventName + " (" + date_to_show + ")"
  end
  
  def find_participation_by_person(person)
    result = nil
    participations.each do |part|
      result = part if (part.person_id == person.id)
    end
    return result
  end
  
end
