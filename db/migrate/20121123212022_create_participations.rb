class CreateParticipations < ActiveRecord::Migration
  def change
    create_table :participations do |t|
      t.string :role
      t.references :person
      t.references :event

      t.timestamps
    end
    add_index :participations, :person_id
    add_index :participations, :event_id
  end
end
