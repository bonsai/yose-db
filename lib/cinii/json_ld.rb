# frozen_string_literal: true

module Cinii
  # Lightweight JSON-LD helpers for the CiNii Research OpenSearch JSON-LD
  # responses. Flattens the well-known OpenSearch envelope (channel + items)
  # into plain hashes so we can store them straight into the jsonb store.
  module JsonLd
    module_function

    TEXT_KEYS = %w[title dc:title name dc:name @value].freeze

    # Extract a human readable text from a JSON-LD value.
    # Values can be String, Array or Hash ({ "title" => [...], "@language" => ... }).
    def text(value)
      parts = collect_text(value)
      parts.flatten.map(&:to_s).map(&:strip).uniq.reject(&:empty?).join(", ")
    end

    def collect_text(value)
      case value
      when Array then value.map { |v| collect_text(v) }
      when Hash
        key = TEXT_KEYS.find { |k| value.key?(k) }
        if key
          collect_text(value[key])
        else
          value.values.map { |v| collect_text(v) }
        end
      else
        [value]
      end
    end
    private_class_method :collect_text

    # Parse an OpenSearch JSON-LD document (v1/v2 CiNii Research).
    def parse(json)
      channel = json["@graph"]&.first || json
      raw_items = channel["items"] || json["items"] || []
      {
        "total" => payload(channel["opensearch:totalResults"])&.to_i || 0,
        "start_index" => payload(channel["opensearch:startIndex"])&.to_i,
        "items_per_page" => payload(channel["opensearch:itemsPerPage"])&.to_i || 0,
        "title" => text(channel["title"]),
        "request" => json["@id"] || channel["@id"],
        "items" => raw_items.map { |it| normalize_item(it) }
      }
    end

    def normalize_item(item)
      see_also = item.dig("rdfs:seeAlso", "@id") || payload(item.dig("rdfs:seeAlso"))
      {
        "id" => payload(item["@id"]) || payload(item.dig("link", "@id")),
        "title" => text(item["title"]),
        "creator" => text(item["dc:creator"]),
        "contributor" => text(item["dc:contributor"]),
        "date" => text(item["dc:date"]),
        "publication" => text(item["prism:publicationName"]),
        "subject" => text(item["subject"]),
        "description" => text(item["description"]),
        "url" => see_also || payload(item["@id"])
      }.compact
    end

    def payload(node)
      return nil if node.nil?
      return node if node.is_a?(String) || node.is_a?(Numeric)

      node.is_a?(Hash) ? node["@id"] || node["@value"] : node
    end
    private_class_method :payload
  end
end