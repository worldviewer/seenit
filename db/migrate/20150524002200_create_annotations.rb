class CreateAnnotations < ActiveRecord::Migration
  def change
    create_table :annotations do |t|
      t.timestamps
      t.string :annotator_schema_version
      t.text :text
      t.text :quote
      t.string :uri
      t.text :ranges
      t.string :user
      t.string :consumer
      t.text :tags
      t.text :permissions
    end
  end
end
