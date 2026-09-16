# frozen_string_literal: true

require "json"
require "securerandom"

module Yose
  class AlreadyExists < StandardError; end

  # Schema-less JSON store built on PostgreSQL jsonb.
  # Port of the original psql/jsonb "Yose" gem onto Rails/ActiveRecord.
  #
  #   store = Yose::Store.new            # table: entries
  #   uid   = store.alloc({ "type" => "講談師", "name" => "神田伯山" })
  #   store.search({ "type" => "講談師" })
  class Store
    DEFAULT_TABLE = "entries"

    def initialize(table = DEFAULT_TABLE)
      @table = table
    end

    attr_reader :table

    # Insert a JSON object. Returns the generated uid (uuid).
    def alloc(obj)
      sql = <<~SQL
        INSERT INTO #{@table} (uid, obj)
        VALUES ($1, $2::jsonb)
        RETURNING uid::text AS uid
      SQL
      uid = SecureRandom.uuid
      query_first(sql, uid, as_json(obj))["uid"]
    end

    # Insert a JSON object unless an object contained by `obj @> $1` already
    # exists. Raises Yose::AlreadyExists in that case.
    def alloc!(obj)
      raise ArgumentError, "obj must be a Hash" unless obj.is_a?(Hash)

      json = as_json(obj)
      if exists_prefix?(json)
        raise AlreadyExists, "already exist #{json}"
      end

      alloc(obj)
    end

    # Free(delete) a record. Returns the freed object, or nil.
    def free(uid)
      sql = <<~SQL
        DELETE FROM #{@table} WHERE uid = $1::uuid
        RETURNING obj
      SQL
      row = query_first(sql, uid)
      row && json(row["obj"])
    end
    alias forget free

    # Fetch a record by uid. Returns parsed Hash, or nil.
    def [](uid)
      sql = <<~SQL
        SELECT obj FROM #{@table} WHERE uid = $1::uuid LIMIT 1
      SQL
      row = query_first(sql, uid)
      row && json(row["obj"])
    end

    # mtime of a record. Returns Time or nil.
    def mtime(uid)
      sql = <<~SQL
        SELECT mtime FROM #{@table} WHERE uid = $1::uuid LIMIT 1
      SQL
      row = query_first(sql, uid)
      row && row["mtime"]
    end

    # Search records whose jsonb object contains `obj` (using @> op).
    def search(obj)
      sql = <<~SQL
        SELECT uid::text AS uid, obj, mtime
        FROM #{@table}
        WHERE obj @> $1::jsonb
        ORDER BY mtime DESC
      SQL
      query_all(sql, as_json(obj))
    end

    # Merge(jsonb concatenation ||) `obj` into the record. Returns merged Hash.
    def update(uid, obj)
      sql = <<~SQL
        UPDATE #{@table} SET obj = obj || $2::jsonb
        WHERE uid = $1::uuid
        RETURNING obj
      SQL
      row = query_first(sql, uid, as_json(obj))
      row && json(row["obj"])
    end
    alias merge update

    # Completely replace the record's object.
    def replace(uid, obj)
      sql = <<~SQL
        UPDATE #{@table} SET obj = $2::jsonb
        WHERE uid = $1::uuid
        RETURNING obj
      SQL
      row = query_first(sql, uid, as_json(obj))
      row && json(row["obj"])
    end

    # Delete a top-level key from the record (using - op). Returns merged Hash.
    def delete(uid, key)
      sql = <<~SQL
        UPDATE #{@table} SET obj = obj - $2
        WHERE uid = $1::uuid
        RETURNING obj
      SQL
      row = query_first(sql, uid, key.to_s)
      row && json(row["obj"])
    end

    # Records whose mtime > since, newest first.
    def recent(since)
      sql = <<~SQL
        SELECT uid::text AS uid, obj, mtime
        FROM #{@table}
        WHERE mtime > $1::timestamptz
        ORDER BY mtime DESC
      SQL
      since = since.utc.iso8601(6) if since.is_a?(Time)
      query_all(sql, since)
    end

    private

    def as_json(obj)
      obj.is_a?(Hash) ? obj.to_json : obj.to_s
    end

    def exists_prefix?(json)
      sql = <<~SQL
        SELECT count(*) AS count FROM #{@table} WHERE obj @> $1::jsonb
      SQL
      query_first(sql, json)["count"].to_i.positive?
    end

    def query_first(sql, *values)
      rows = exec(sql, values)
      rows.first
    end

    def query_all(sql, *values)
      exec(sql, values).map { |r| { "uid" => r["uid"], "obj" => json(r["obj"]), "mtime" => r["mtime"] } }
    end

    def exec(sql, values)
      # Rails 8.x pg adapter takes a flat array of bind values (or QueryAttribute).
      connection.exec_query(sql, "Yose::Store", values, prepare: false).to_a
    end

    def connection
      ActiveRecord::Base.lease_connection
    end

    def json(value)
      value.is_a?(String) ? JSON.parse(value) : value
    end
  end
end