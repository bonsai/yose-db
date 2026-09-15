# frozen_string_literal: true

module Api
  module V1
    class KodanshiController < ApplicationController
      before_action :store

      # GET /api/v1/kodanshi
      def index
        render json: { count: @store.search({ "type" => "講談師" }).size,
                       kodanshi: @store.search({ "type" => "講談師" }) }
      end

      # GET /api/v1/kodanshi/:uid
      def show
        obj = @store[params[:id]]
        return render(json: { error: "not found" }, status: :not_found) unless obj

        render json: { uid: params[:id], obj: obj }
      end

      # POST /api/v1/kodanshi/sync  (body: { names: ["神田伯山"] } 省略で全員。CINII_APPID 必須)
      def sync
        names = params[:names]
        @store.search({ "type" => "講談師" }).empty? ? Kodanshi.load_roster!(store: @store) : nil
        results = Kodanshi.sync_ciinii!(client: Cinii::Client.new, store: @store, names: names)
        render json: { synced: results }
      rescue Cinii::MissingAppId => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def store
        @store ||= Yose::Store.new
      end
    end
  end
end