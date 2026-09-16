# frozen_string_literal: true

# Yose::Store のレコード ({"uid","obj","mtime"}) を講談師リスト項目として返す。
class Api::V1::KodanshiItemSerializer
  include Alba::Resource

  attribute :uid do |r|
    r["uid"]
  end

  attribute :obj do |r|
    r["obj"]
  end

  attribute :mtime do |r|
    r["mtime"]&.iso8601
  end
end