class Gender
  UNSPECIFIED = 0
  MALE = 1
  FEMALE = 2
  
  def self.to_string(gender)
    case gender
    when UNSPECIFIED
      "unspecified"
    when MALE 
      "male"
    when FEMALE 
      "female"
    else 
      "error"
    end
  end
end

class Person < ActiveRecord::Base
  has_many :participations, :dependent => :destroy
  has_many :events, :through => :participations
    
  # these are database attributes for the person
  attr_accessible :firstName, :gender, :lastName, :middleName
  
  # these are mass-assignment attributes I want on the object but I'll manage their storage
  attr_accessible :dob
  
  # this is a mess to get around a rails bug to tell it how to map my non-db attr to the date class
  composed_of :dob, 
              :class_name => 'Date', 
              :mapping => %w(Date to_s), 
              :constructor => Proc.new{ |item| item}, 
              :converter => Proc.new{ |item| item }
  
  validates :firstName, :presence => true
  validates :lastName, :presence => true  

  # this is strange - I thought attr_accessible above would create these for me and
  # encompass attr_accessor functionality.  I need attr_accessible to handle the
  # mass assignment, and just adding attr_accessor didn't seem to work.  Without
  # these manually defined, dob ended up not stored on the instance.  Perhaps some
  # scope issue I don't yet understand?
  def dob
    @dob
  end
  def dob=(new_dob)
    @dob = new_dob
  end

  # initialize an instance variable with the dob anytime we load
  # note that we use callbacks rather than "pass-through" to the birth event
  # so the birth event doesn't get created until after the person has been validated / saved
  after_find :do_after_find
  def do_after_find
    event_birth = birth_event
    if (!event_birth.nil?)
      self.dob = event_birth.startDate
    end
  end
  
  # automatically create the birth event if I have a date for it
  after_create :do_after_create
  def do_after_create
    birth(dob) unless dob.nil?
  end
  
  # update the birth event anytime the person is updated
  after_update :do_after_update
  def do_after_update
    if (!dob.nil?)
      if (birth_event.nil?)
        birth(dob)
      else
        birth_event.startDate = dob
        birth_event.save
      end
    end
  end
  
  def name(bFull = true)
    strResult = firstName unless firstName.nil?
    if (bFull)
      strResult = strResult + " " unless (strResult.nil? or middleName.nil?)
      strResult = strResult + middleName unless middleName.nil?
    end
    strResult = strResult + " " unless (strResult.nil? or lastName.nil?)
    strResult = strResult + lastName unless lastName.nil?
    strResult
  end
  
  def short_name
    name(false)
  end  
  
  def participate(role, event)
    # make sure there is only 1 birth or death event
    if ((role != :child and role != :deceased) or
        (role == :child and birth_event.nil?) or 
        (role == :deceased and death_event.nil?))
      part = Participation.new(:role => role, :event => event, :person => self)
      part.save
    else
      nil # throw an exception?
    end
  end
  
  def birth(dBirth, parentOne = nil, parentTwo = nil)
    
    # add the birth event to myself
    eBirth = Event.new(:eventName => "#{short_name} Birth", :startDate => dBirth)
    eBirth.save
    participate(:child, eBirth)
    
    # add the birth event to each of my parents
    parentOne.participate(:parent, eBirth) unless parentOne.nil?
    parentTwo.participate(:parent, eBirth) unless parentTwo.nil?
  end
  
  def marry(spouse, dateWedding)
    eMarriage = Event.new(:eventName => "#{short_name} & #{spouse.short_name} Marriage", :startDate => dateWedding)
    eMarriage.save
    participate(:spouse, eMarriage)
    spouse.participate(:spouse, eMarriage)
  end
  
  def die(date_died)
    death_event = Event.new(:eventName => "#{short_name} Death", :startDate => date_died)
    death_event.save
    participate(:deceased, death_event)
    #TODO: only participate in death event if you are still married (need divorce events to do this)
    # for now we'll approximate by widowing all living spouses
    #spice.each do |s|
    #  s.participate(:widow, death_event) if s.is_alive
    #end
  end

  # return the array of events I'm paricipating in for the role provided
  def find_events(role)
    # note - Ruby should have a way to do this in one step - but I can't find it
    # map includes all elements, select includes entire object, need something that goes in between
    # not really sure why I need the to_s, but role is not string if I pass in :ROLE
    parts = participations.select { |p| (!p.event.nil? and p.role == role.to_s) }
    events = parts.map { |p| p.event }
  end

  # return the array of people I'm paricipating with for the role provided
  # this means finding the events for a role, then finding others connected to it
  # note that it never returns me
  def find_other_people(my_role, their_role)
    events = find_events(my_role)
    other_participants = Array.new
    events.each do |e| 
      e.participations.each do |p|
       other_participants << p.person if (p.role == their_role.to_s and !p.person.nil? and p.person != self)
      end
    end
    other_participants
  end


  # enforce just a single event for a role
  def find_event(role)
    events = find_events(role)
    event = events[0] # if (!events.nil? and events.count == 0)
  end
  
  def birth_event
    find_event(:child)
  end
  
  def death_event
    find_event(:deceased)
  end
  
  def marriage_events
    find_events(:spouse)
  end
  
  # return the date on which the person was born
  def born
    return birth_event.startDate if !birth_event.nil?
  end
  
  def died
    return death_event.startDate if !death_event.nil?
  end
  
  def title
    result = "#{name} (#{birthyear_to_s} - #{deathyear_to_s})"
  end
  
  def title_tree
    result = "#{name}"
    spouses = spice
    if (!spouses.nil?)
      result = result + " (m. "
      spouses.each do |spouse|
        result = result + spouse.name
      end
      result = result + ")"
    end
  end
  
  def children
    find_other_people(:parent, :child)
  end
  
  def parents
    find_other_people(:child, :parent)
  end
  
  def is_parent_of?(possible_child)
    children.include?(possible_child)
  end
  
  def is_spouse_of?(possible_spouse)
    spice.include?(possible_spouse)
  end
  
  def spice
    find_other_people(:spouse, :spouse)
  end
  
  def siblings(include_step_siblings = false, include_half_siblings = false)
    
    # create an empty list
    sibs = Array.new
    
    # who is my father?
    my_parents = parents
    
    # who are my parents' children who are not me
    my_parents.each do |par|
      par.children.each do |sib|
        sibs << sib if (sib != self) # TBD: only add to array if item is not already in
      end
    end
    
    # return all of my parents' children who are not me
    return sibs
    
  end
  
  # returns a hash with each key being the person object, and each value the relation string
  def immediate_family
    
    # collect the family in a hash
    family = Hash.new
    
    # get all spouses and map their label
    spice.each do |relative| 
      if (relative.gender == Gender::MALE)
        family[relative] = "Husband"
      elsif (relative.gender == Gender::FEMALE)
        family[relative] = "Wife"
      else
        family[relative] = "Spouse"
      end
    end
    
    children.each do |relative| 
      if (relative.gender == Gender::MALE)
        family[relative] = "Son"
      elsif (relative.gender == Gender::FEMALE)
        family[relative] = "Daughter"
      else
        family[relative] = "Child"
      end
    end
    
    parents.each do |relative| 
      if (relative.gender == Gender::MALE)
        family[relative] = "Father"
      elsif (relative.gender == Gender::FEMALE)
        family[relative] = "Mother"
      else
        family[relative] = "Parent"
      end
    end
    
    siblings.each do |relative|
      if (relative.gender == Gender::MALE)
        family[relative] = "Brother"
      elsif (relative.gender == Gender::FEMALE)
        family[relative] = "Sister"
      else
        family[relative] = "Sibling"
      end
    end
    
    family
    
  end
  
  
  # collect most important dates such as birth, death, marriages
  def key_dates
    events = Array.new
    events << birth_event if !birth_event.nil?
    events << death_event if !death_event.nil?
    events.concat(marriage_events) if (!marriage_events.nil? and marriage_events.count > 0)
    events
  end
  
  # date i first became a parent - useful to estimate my lifespan if my own birthdate is not known
  def parenthood_date
    earliest_child_birthdate = nil
    children.each do |child|
      child_birthdate = child.born
      if (!child_birthdate.nil? && (earliest_child_birthdate.nil? || child_birthdate < earliest_child_birthdate))
        earliest_child_birthdate = child_birthdate
      end
    end
    return earliest_child_birthdate
  end

  # date my youngest parent was born - useful to estimate my lifespan if my own birthdate is not known
  def babyhood_date
    youngest_parent_birthdate = nil
    parents.each do |parent|
      parent_birthdate = parent.born
      if (!parent_birthdate.nil? && (youngest_parent_birthdate.nil? || parent_birthdate > youngest_parent_birthdate))
        youngest_parent_birthdate = parent_birthdate
      end
    end
    return youngest_parent_birthdate
  end

  # date my first parent died - useful to estimate my lifespan if my own birthdate is not known
  def semi_orphan_date
    first_parent_deathdate = nil
    parents.each do |parent|
      parent_deathdate = parent.died
      if (!parent_deathdate.nil? && (first_parent_deathdate.nil? || parent_deathdate < first_parent_deathdate))
        first_parent_deathdate = parent_deathdate
      end
    end
    return first_parent_deathdate    
  end  

  # date my last parent died - useful to estimate my lifespan if my own birthdate is not known
  def orphan_date
    last_parent_deathdate = nil
    parents.each do |parent|
      parent_deathdate = parent.died
      if (!parent_deathdate.nil? && (last_parent_deathdate.nil? || parent_deathdate > last_parent_deathdate))
        last_parent_deathdate = parent_deathdate
      end
    end
    return last_parent_deathdate
  end
  
  # find earliest possible birthdate based on parents and kids
  def earliest_birthdate
    
    # the earliest possible is 10 years after my youngest parent was born 
    earliest = babyhood_date
    if (!earliest.nil?)
      earliest = earliest + 10.years
    end
    
    return earliest
  end

  # find latest possible birthdate based on parents and kids
  def latest_birthdate
    
    # the latest possible birthdate is 10 years before my first child was born
    latest = parenthood_date
    if (!latest.nil?)
      latest = latest - 10.years
    end
    
    # if not known from my child's birth then at least i know i was born before 1 of my parents died
    if (latest.nil?)
      latest = semi_orphan_date
    end
    
    return latest
  end
  
  # either known birthate or calculated best guess at earliest based on parents/kids
  def earliest_known_birthdate
    earliest = born
    if (earliest.nil?)
      earliest = earliest_birthdate
    end
    if (earliest.nil?)
      earliest = latest_birthdate
    end
    return earliest
  end
  
  
  # return birthdate range as string
  def estimated_birthyear_range_to_s
    earliest = earliest_birthdate
    latest = latest_birthdate
    if (earliest.nil? && latest.nil?)
      result = "?"
    elsif (earliest.nil?)
      result = "before #{latest.year}"
    elsif (latest.nil?)
      result = "after #{earliest.year}"
    else
      result = "#{earliest.year}/#{latest.year}"
    end
    return result
  end

  # earliest possible deathdate is immediately after birth (or earliest possible birthdate)
  def earliest_deathdate
    earliest = earliest_known_birthdate
  end

  # latest possible deathdate is 100 years after birthdate (or latest possible birthdate)  
  def latest_deathdate
    date_born = born
    if (!date_born.nil?)
      latest = date_born + 120.years
    elsif
      latest = latest_birthdate + 120.years
    end
  end

  # determine if this person is already dead based on being marked as dead or being really old
  def is_dead?
    is_dead = !death_event.nil?
    if (!is_dead)
      date_was_born = earliest_known_birthdate
      is_dead = (!date_was_born.nil? && date_was_born < (120.years.ago).to_date)
    end
    return is_dead
  end

  # return estimated deathyeat range as string
  def estimated_deathyear_range_to_s
    result = ""
    
    # only bother with this calculation if this person is dead with an unkwown date
    # or the person would be over 120 years old
    if (is_dead?)
      earliest = earliest_deathdate
      latest = latest_deathdate
      if (earliest.nil? && latest.nil?)
        result = "?"
      elsif (earliest.nil?)
        result = "before #{latest.year}"
      elsif (latest.nil?)
        result = "after #{earliest.year}"
      else
        result = "#{earliest.year}/#{latest.year}"
      end
    end
    return result
  end
  
  def birthyear_to_s
    birthdate = born
    if (!birthdate.nil?)
      result = birthdate.year.to_s
    else
      result = estimated_birthyear_range_to_s
    end
  end
  
  def deathyear_to_s
    if (is_dead?)
      deathdate = died
      if (!deathdate.nil?)
        result = deathdate.year.to_s
      else
        result = estimated_deathyear_range_to_s
      end
    else
      result = ""
    end
    return result
  end
  
  def gender_to_s
    Gender.to_string(gender)
  end
  
  def gender_short
    result = nil
    if (gender == Gender::MALE)
      result = "m"
    elsif (gender == Gender::FEMALE)
      result = "f"
    end
  end
  
  def to_s
    result = ""
    if (!firstName.nil?)
      result = firstName
    else
      result = gender_to_s
    end
    if (!lastName.nil?)
      if (!result.blank?)
        result += " "
      end
      result += lastName
    end
    return result
  end

  # funny data structure results: hash of nodes, where each node is the key, and the value is the depth
  # each node is an array of up to two items.  First item is always the person at the node, second (if provided) if an array of spouses  
  # we should create a family-tree-node class to encapsulate this fun
  def descendants(result = nil, depth = 0)
    
    if (result.nil?)
      result = Hash.new
    end
    
    children.each do |kid|
      node = Array.new
      node[0] = kid
      kid_spice = kid.spice
      if (!kid_spice.nil? && kid_spice.length > 0)
        # TBD: I know there is a Ruby way to copy an array but can't look it up on the plane - just copy myself for now
        spouse_list = Array.new
        kid_spice.each do |s|
          spouse_list << s
        end
        node[1] = spouse_list
      end
      result[node] = depth
      kid.descendants(result, depth + 1)
    end    
    
    return result
    
  end

  # funny data structure in the other way - see comment on descendants
  def ascendants(result = nil, depth = 0)
    
    if (result.nil?)
      result = Hash.new
    end
    
    parents.each do |par|
      node = Array.new
      node[0] = par
      par_spice = par.spice
      if (!par_spice.nil? && par_spice.length > 0)
        # TBD: I know there is a Ruby way to copy an array but can't look it up on the plane - just copy myself for now
        spouse_list = Array.new
        par_spice.each do |s|
          spouse_list << s
        end
        node[1] = spouse_list
      end
      result[node] = depth
      par.ascendants(result, depth + 1)
    end    
    
    return result
    
  end

  
  
end