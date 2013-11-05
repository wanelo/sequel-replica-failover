require 'usdt'

module Sequel
  module ReplicaFailover
    class DTraceProvider
      attr_reader :provider

      def initialize
        @provider = USDT::Provider.create(:ruby, :sequel_replica_failover)
      end

      def stick
        @stick_probe ||= provider.probe(:connection, :stick, :integer)
      end

      def unstick
        @unstick_probe ||= provider.probe(:connection, :unstick, :string)
      end

      def self.provider
        @provider ||= new.tap do |p|
          p.stick
          p.unstick
          p.provider.enable
        end
      end
    end
  end
end
