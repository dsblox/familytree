class CreatePeople < ActiveRecord::Migration
  def change
    create_table :people do |t|
      t.string :firstName
      t.string :lastName
      t.string :middleName
      t.integer :gender

      t.timestamps
    end
  end
end
