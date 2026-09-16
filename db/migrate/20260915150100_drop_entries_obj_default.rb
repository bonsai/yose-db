class DropEntriesObjDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_default :entries, :obj, from: "{}", to: nil
  end
end