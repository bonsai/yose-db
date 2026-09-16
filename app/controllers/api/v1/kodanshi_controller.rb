# frozen_string_literal: true

module Api
  module V1
    class KodanshiController < ApplicationController
      before_action :store

      # GET /api/v1/kodanshi
      def index
        list = @store.search({ "type" => "講談師" })
        render json: { count: list.size,
                       kodanshi: Api::V1::KodanshiItemSerializer.new(list).serializable_hash }
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

      # GET /api/v1/kodanshi/all_graph  (全講談師: ノード+エッジの精製グラフ)
      def all_graph
        render json: Api::V1::AllGraphSerializer.new(Kodanshi::Graph.all_graph(store: @store)).serializable_hash
      end

      # GET /api/v1/kodanshi/zenza  (前座ランキング)
      def zenza
        render json: Api::V1::ZenzaSerializer.new(Kodanshi::Graph.zenza(store: @store)).serializable_hash
      end

      private

      def store
        @store ||= Yose::Store.new
      end
    end
  end
end