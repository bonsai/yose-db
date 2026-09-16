# frozen_string_literal: true

# 全講談師グラフ (Kodanshi::Graph.all_graph の文字キー Hash をシリアライズ)。
class Api::V1::AllGraphSerializer
  include Alba::Resource

  attribute(:meta)  { |h| h["meta"] }
  attribute(:ranks) { |h| h["ranks"] }
  attribute(:nodes) { |h| h["nodes"] }
  attribute(:edges) { |h| h["edges"] }
end