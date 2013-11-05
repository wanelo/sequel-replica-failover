require 'spec_helper'

describe Sequel::ReplicaFailover::DTraceProvider do
  describe 'initialize' do
    it 'creates a new provider' do
      USDT::Provider.should_receive(:create).with(:ruby, :sequel_replica_failover)
      Sequel::ReplicaFailover::DTraceProvider.new
    end
  end

  describe 'probes' do
    let(:provider) { Sequel::ReplicaFailover::DTraceProvider.new }

    describe '#stick' do
      it 'is a probe' do
        expect(provider.stick).to be_a USDT::Probe
      end

      it 'has :replica_failover for its function' do
        expect(provider.stick.function).to eq(:connection)
      end

      it 'has :stick for its name' do
        expect(provider.stick.name).to eq(:stick)
      end

      it 'takes an integer argument' do
        expect(provider.stick.arguments).to eq([:integer])
      end
    end

    describe '#unstick' do
      it 'is a probe' do
        expect(provider.unstick).to be_a USDT::Probe
      end

      it 'has :replica_failover for its function' do
        expect(provider.unstick.function).to eq(:connection)
      end

      it 'has :unstick for its name' do
        expect(provider.unstick.name).to eq(:unstick)
      end

      it 'takes a string argument' do
        expect(provider.unstick.arguments).to eq([:string])
      end
    end
  end

  describe '::provider' do
    it 'returns a DTraceProvider' do
      provider = Sequel::ReplicaFailover::DTraceProvider.provider
      expect(provider).to be_a(Sequel::ReplicaFailover::DTraceProvider)
    end
  end
end
