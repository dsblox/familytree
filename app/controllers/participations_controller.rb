class ParticipationsController < ApplicationController
  
  # GET /participations/new
  def new
    # we'll be able to make this dynamic based on the presence of a person_id or event_id
    @person = Person.find(params[:person_id])
    @event_type = params[:event_type]
    @participation = @person.participations.build

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @participation }
    end
  end

  # GET /participation/1/edit
  def edit
    @participation = Participation.find(params[:id])
  end
  
  def valid_date_fields?(date_hash)
    (!date_hash.nil? and date_hash[:year].to_s != "" and date_hash[:month].to_s != "" and date_hash[:day].to_s != "")
  end

  def create
    params[:participation].each { |arg| puts arg }
    params.each { |p| puts p }
    
    
    # create the participation off the person's list - we assume we're created off a base person for now
    @person = Person.find(params[:person_id])
    puts "==> Person: #{@person}"
    
    # pull out and build the event date since we can't seem to get activerecord to do it for us
    event_hash = params[:event_date]
    event_date = Date.new(event_hash[:year].to_i,event_hash[:month].to_i,event_hash[:day].to_i) if valid_date_fields?(event_hash)
    
    # pull out the pieces needed to create the rest of the event
    event_type = params[:participation][:event_type]
    event_id = params[:participation][:event_id]
    other_person1_id = params[:participation][:person1_id]
    other_person2_id = params[:participation][:person2_id]
    other_person1_full_name = params[:participation][:person1_full_name]
    other_person2_full_name = params[:participation][:person2_full_name]
    
    # if valid ids were specified then use those and ignore names provided
    other_person1 = Person.find(other_person1_id) if !(other_person1_id.to_s == '')
    if (other_person1.nil?)
      if (!other_person1_full_name.nil?) 
        split_name(other_person1_full_name)
        other_person1 = Person.new(:firstName => @first_name, :middleName => @middle_name, :lastName => @last_name)
      end
    end
    other_person2 = Person.find(other_person2_id) if !(other_person2_id.to_s == '')
    if (other_person2.nil?)
      if (!other_person2_full_name.nil?) 
        split_name(other_person2_full_name)
        other_person2 = Person.new(:firstName => @first_name, :middleName => @middle_name, :lastName => @last_name)
      end
    end
    if (!event_id.nil?)
      event = Event.find(event_id)
    end
    
    # if we're having a child parse the name, create the child, and mark the parents
    if (event_type == "have a kid")
      kid = other_person1
      spouse = other_person2
      
      # see if this person's birth event already exists before creating another
      event = kid.birth_event
      puts "==> event: #{event.class}"
      if (event.nil?)
        kid.birth(event_date, @person, spouse)
      elsif (!@person.is_parent_of?(kid))
        @person.participate(:parent, event)
        if (!spouse.is_parent_of?(kid)) # note: if original person was already a parent we don't add the other parent
          spouse.participate(:parent, event)
        end
      else
        puts "participations_controller:create() - trying to add parent-child relationship that already exists"
      end
      
    # if we're getting married just marry them
    elsif (event_type == "marry someone")
      spouse = other_person1
      puts "==> Spouse: #{spouse}"
      if (!@person.is_spouse_of?(spouse))
        @person.marry(spouse, event_date) if event.nil?
      else
        puts "participations_controller:create() - trying to add marriage that already exists"
      end
      
    # if we're adding a parent then add the parents to my birth event
    elsif (event_type == "add a parent")
      puts "adding a parent"
      parent1 = other_person1
      parent2 = other_person2
      parent1.save
      parent2.save
      event = @person.birth_event
      if (event.nil?)
        @person.birth(event_date, parent1, parent2)
      else
        puts "==> adding parents"
        parent1.participate(:parent, event)
        parent2.participate(:parent, event)
        
        # it is possible we're adding parents to a person who didn't have a birthday set
        if (event.startDate.nil? and !event_date.nil?)
          puts "==> event_date: #{event_date}"
          event.startDate = event_date
          event.save
        end
      end
    
    # record a person's death: that they have died, and if known, when they died
    # allows update of a death date - is this best???
    elsif (event_type == "die")
      event = @person.death_event
      if (event.nil?)
        @person.die(event_date)
      else (event.startDate.nil?)
        event.startDate = event_date
        event.save
      end
    end
    
    # @participation = @person.participations.create(params[:participation])
    
    # we assume for now we always create participations from people (change?)
    redirect_to person_path(@person)
  end
  
  # DELETE /participations/1
  # DELETE /participations/1.json
  def destroy
    @participation = Participation.find(params[:id])
    @participation.destroy

    respond_to do |format|
      format.html { redirect_to people_url }
      format.json { head :no_content }
    end
  end
  
  # TODO: Move these into the person model somehow
  def init_fields(first_name = nil, middle_name = nil, last_name = nil)
    @first_name = first_name
    @last_name = last_name
    @middle_name = middle_name
  end
  def split_name(full_name)
    names = full_name.split
    if names != nil
      if (names.kind_of?(Array)) 
        first_name = names[0]
        len = names.length
        if len >= 2
          last_name = names[len-1]
        end
        if len >= 3
          middle_names = names[1,len-2].join(" ") 
        end
      elsif
        first_name = name
      end
    end
    init_fields(first_name, middle_names, last_name)
  end
    
end
