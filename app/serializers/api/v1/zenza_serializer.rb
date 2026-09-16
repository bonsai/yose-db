# frozen_string_literal: true

# 前座ランキング (Kodanshi::Graph.zenza の文字キー Hash をシリアライズ)。
class Api::V1::ZenzaSerializer
  include Alba::Resource

  attribute(:meta)    { |h| h["meta"] }
  attribute(:members) { |h| h["members"] }
end