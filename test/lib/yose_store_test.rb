# frozen_string_literal: true

require "test_helper"

class YoseStoreTest < ActiveSupport::TestCase
  def setup
    @store = Yose::Store.new
  end

  def teardown
    @store.search({}).each { |r| @store.free(r["uid"]) }
  end

  def test_alloc_returns_uid_and_fetch
    uid = @store.alloc({ "foo" => "bar", "ary" => [1, 2, 3] })
    assert_kind_of String, uid
    assert_equal({ "foo" => "bar", "ary" => [1, 2, 3] }, @store[uid])
  end

  def test_alloc_with_string_json
    uid = @store.alloc('{"foo":"bar"}')
    assert_equal({ "foo" => "bar" }, @store[uid])
  end

  def test_alloc_bang_uniqueness
    assert @store.alloc!({ "foo" => "bar" })
    assert_raises(Yose::AlreadyExists) { @store.alloc!({ "foo" => "bar" }) }
    assert @store.alloc!({ "foo" => "baz" })
  end

  def test_alloc_bang_requires_hash
    assert_raises(ArgumentError) { @store.alloc!("string") }
  end

  def test_free
    uid = @store.alloc({ "foo" => "bar" })
    assert_equal({ "foo" => "bar" }, @store.free(uid))
    assert_nil @store[uid]
  end

  def test_search_containment
    a = @store.alloc!({ "type" => "従業員", "name" => "関将俊" })
    b = @store.alloc!({ "type" => "従業員", "name" => "池澤一廣" })
    _c = @store.alloc!({ "type" => "author", "name" => "関将俊" })

    assert_equal [a, b], @store.search({ "type" => "従業員" }).map { |r| r["uid"] }
    assert_equal [a, b], @store.search({ "type" => "従業員", "name" => "関将俊" }).map { |r| r["uid"] },
                 "containment prefix search must match objects that extend the query"
  end

  def test_merge_concatenates
    uid = @store.alloc({ "foo" => "bar", "bar" => "baz" })
    merged = @store.merge(uid, { "foo" => "hoge" })
    assert_equal({ "foo" => "hoge", "bar" => "baz" }, merged)
    assert_equal({ "foo" => "hoge", "bar" => "baz" }, @store[uid])
  end

  def test_replace
    uid = @store.alloc({ "foo" => "bar", "bar" => "baz" })
    assert_equal({ "hoge" => "fuga" }, @store.replace(uid, { "hoge" => "fuga" }))
    assert_equal({ "hoge" => "fuga" }, @store[uid])
  end

  def test_delete_key
    uid = @store.alloc({ "foo" => "bar", "bar" => "baz" })
    assert_equal({ "foo" => "bar" }, @store.delete(uid, "bar"))
    assert_equal({ "foo" => "bar" }, @store[uid])
  end

  def test_mtime_and_recent
    one = @store.alloc({ "foo" => "bar" })
    two = @store.alloc({ "foo" => "bar" })
    mtime = @store.mtime(two)
    three = @store.alloc({ "foo" => "bar" })

    assert_equal 1, @store.recent(mtime).size
    recent = @store.recent(@store.mtime(one))
    assert_equal 2, recent.size
    assert_equal three, recent[0]["uid"]
    assert_equal two, recent[1]["uid"]
  end

  def test_mtime_bumps_on_update
    uid = @store.alloc({ "foo" => "bar" })
    before = @store.mtime(uid)
    sleep 0.05
    @store.merge(uid, { "x" => 1 })
    assert_operator @store.mtime(uid), :>, before
  end
end