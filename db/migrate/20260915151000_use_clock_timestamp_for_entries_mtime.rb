class UseClockTimestampForEntriesMtime < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION yose_entry_touch()
      RETURNS trigger AS $$
      BEGIN
        NEW.mtime := clock_timestamp();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute "DROP TRIGGER IF EXISTS entries_moddatetime ON entries;"
    execute <<~SQL
      CREATE TRIGGER entries_touch
        BEFORE UPDATE ON entries
        FOR EACH ROW
        EXECUTE PROCEDURE yose_entry_touch();
    SQL

    # now() はトランザクション開始時刻で固定されるため、同一トランザクション内で
    # mtime が進まない。clock_timestamp() を既定値にして文ごとに進める。
    change_column_default :entries, :mtime, -> { "clock_timestamp()" }
  end

  def down
    change_column_default :entries, :mtime, -> { "CURRENT_TIMESTAMP" }
    execute "DROP TRIGGER IF EXISTS entries_touch ON entries;"
    execute "DROP FUNCTION IF EXISTS yose_entry_touch();"
    execute <<~SQL
      CREATE TRIGGER entries_moddatetime
        BEFORE UPDATE ON entries
        FOR EACH ROW
        EXECUTE PROCEDURE moddatetime (mtime);
    SQL
  end
end