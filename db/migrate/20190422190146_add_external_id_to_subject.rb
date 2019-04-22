class AddExternalIdToSubject < ActiveRecord::Migration[5.2]
  def change
    add_column :subjects, :external_id, :string, null: true
  end
end
