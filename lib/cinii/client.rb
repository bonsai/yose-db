# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Cinii
  class MissingAppId < StandardError; end
  class ApiError < StandardError; end

  # Minimal CiNii Research OpenSearch client (JSON-LD).
  #
  #   client = Cinii::Client.new(appid: ENV["CINII_APPID"])
  #   res = client.search(kind: :articles, q: "神田伯山")
  #   res.total # => 12
  #   res.items # => [{ "id" => "https://cir.nii.ac.jp/crid/...", "title" => "...", ... }]
  class Client
    ENDPOINTS = {
      all: "https://cir.nii.ac.jp/opensearch/all",
      data: "https://cir.nii.ac.jp/opensearch/data",
      articles: "https://cir.nii.ac.jp/opensearch/articles",
      books: "https://cir.nii.ac.jp/opensearch/books",
      dissertations: "https://cir.nii.ac.jp/opensearch/dissertations",
      projects: "https://cir.nii.ac.jp/opensearch/projects",
      researchers: "https://cir.nii.ac.jp/opensearch/v2/researchers"
    }.freeze

    Response = Data.define(:kind, :total, :start_index, :items_per_page, :title, :request, :items)

    attr_reader :appid

    def initialize(appid: ENV["CINII_APPID"], base_url: nil, open_timeout: 10, read_timeout: 30)
      @appid = appid&.to_s&.strip
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @endpoints = ENDPOINTS.merge(base_url ? { default: base_url } : {})
    end

    # Search CiNii Research.
    #   kind: one of Cinii::Client::ENDPOINTS keys (:all, :articles, :books, :researchers, ...)
    #   params: q / author / name / creator / count / start / sortorder / lang / from / until ...
    def search(kind:, **params)
      raise MissingAppId, "CINII_APPID is required. Register at https://support.nii.ac.jp/ja/cinii/api/developer" unless appid

      url = uri_for(kind)
      params = { appid: appid, format: "json", lang: "ja", count: 20, **params }
      url.query = URI.encode_www_form(params.compact)

      json = get(url)
      parsed = Cinii::JsonLd.parse(json)
      Response.new(
        kind: kind.to_s,
        total: parsed["total"],
        start_index: parsed["start_index"],
        items_per_page: parsed["items_per_page"],
        title: parsed["title"],
        request: parsed["request"],
        items: parsed["items"]
      )
    end

    # Fetch a detail JSON-LD (e.g. the rdfs:seeAlso @id of an item) and
    # flatten it to a plain Hash.
    def fetch(item_url)
      raise MissingAppId, "CINII_APPID is required" unless appid

      url = URI(item_url)
      qs = URI.decode_www_form(url.query.to_s)
      qs << ["appid", appid] unless qs.any? { |k, _| k == "appid" }
      url.query = URI.encode_www_form(qs)

      Cinii::JsonLd.parse(get(url))
    end

    private

    def uri_for(kind)
      endpoint = @endpoints[kind.to_sym] || @endpoints[:all]
      URI(endpoint)
    end

    def get(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      req = Net::HTTP::Get.new(url)
      req["User-Agent"] = "yose-db (#{ENV['CINII_USER_AGENT'] || 'Rails'})"
      req["Accept"] = "application/ld+json"

      res = http.request(req)
      raise ApiError, "CiNii API #{res.code} for #{url}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    rescue JSON::ParserError => e
      raise ApiError, "CiNii API returned non-JSON: #{e.message}"
    end
  end
end