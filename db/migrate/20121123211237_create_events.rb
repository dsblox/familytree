class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :eventName
      t.date :startDate
      t.date :endDate

      t.timestamps
    end
  end
end
