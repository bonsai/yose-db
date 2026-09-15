class CreateEntries < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    execute "CREATE EXTENSION IF NOT EXISTS moddatetime;"

    create_table :entries, primary_key: :uid, id: :uuid, default: nil do |t|
      t.jsonb :obj, null: false, default: {}
      t.datetime :mtime, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    execute <<~SQL
      CREATE TRIGGER entries_moddatetime
        BEFORE UPDATE ON entries
        FOR EACH ROW
        EXECUTE PROCEDURE moddatetime (mtime);
    SQL

    add_index :entries, :obj, using: :gin, opclass: "jsonb_path_ops"
  end

  def down
    execute "DROP TRIGGER IF EXISTS entries_moddatetime ON entries;"
    drop_table :entries
  end
end