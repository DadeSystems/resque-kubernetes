# frozen_string_literal: true

module Resque
  module Kubernetes
    # Wraps Kubeclient::Client to retry timeout errors
    class RetriableClient
      attr_accessor :kubeclient, :core_kubeclient

      def initialize(client)
        self.kubeclient = client
        self.core_kubeclient = ::Kubeclient::Client.new(
          URI(client.instance_variable_get(:@api_endpoint).to_s.gsub(/apis\/batch$/, 'api/')),
          client.instance_variable_get(:@api_version),
          ssl_options: client.instance_variable_get(:@ssl_options),
          auth_options: client.instance_variable_get(:@auth_options)
        )
      end

      def method_missing(method, *args, &block)
        if kubeclient.respond_to?(method)
          Retriable.retriable(on: {Kubeclient::HttpError => /Timed out/}) do
            kubeclient.send(method, *args, &block)
          end
        elsif core_kubeclient.respond_to?(method)
          Retriable.retriable(on: {Kubeclient::HttpError => /Timed out/}) do
            core_kubeclient.send(method, *args, &block)
          end
        else
          super
        end
      end

      def respond_to_missing?(method)
        kubeclient.respond_to?(method)
      end
    end
  end
end
