require 'spec_helper'

describe Sequel::ShardedSingleFailoverConnectionPool do
  CONNECTION_POOL_DEFAULTS = {:pool_retry_count => 3,
                              :pool_stick_timeout => 15,
                              :pool_timeout=>5,
                              :pool_sleep_time=>0.001,
                              :max_connections=>4,
                              :pool_class => Sequel::ShardedSingleFailoverConnectionPool,
                              :servers => { :read_only => {} } }

  mock_db = lambda do |*a, &b|
    db = Sequel.mock
    (class << db; self end).send(:define_method, :connect){|c| b.arity == 1 ? b.call(c) : b.call} if b
    if b2 = a.shift
      (class << db; self end).send(:define_method, :disconnect_connection){|c| b2.arity == 1 ? b2.call(c) : b2.call}
    end
    db
  end

  after do
    Sequel::ShardedSingleFailoverConnectionPool.clear_on_retry_callbacks
    Sequel::ShardedSingleFailoverConnectionPool.clear_on_reset_callbacks
  end

  let(:msp) { proc { @max_size=3 } }
  let(:connection_pool) { Sequel::ConnectionPool.get_pool(mock_db.call(proc { |c| msp.call }) { :got_connection }, CONNECTION_POOL_DEFAULTS) }

  describe '#hold' do
    context 'with read_only server' do
      context 'when block raises a database connection error' do
        it 'fails over' do
          call_count = 0
          allow(connection_pool).to receive(:failover!)
          connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 }
          expect(connection_pool).to have_received(:failover!)
        end

        it 'retries until the a successful connection is made' do
          call_count = 0
          expect {
            connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 }
          }.not_to raise_error
          expect(call_count).to eq(2)
        end

        it 'only retries N number of times before actually raising the error' do
          call_count = 0
          expect {
            connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError }
          }.to raise_error(Sequel::DatabaseDisconnectError)
          expect(call_count).to eq(3)
        end

        it 'sticks for N number of seconds to a working connection' do
          Timecop.freeze -16 do
            call_count = 0
            expect {
              connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 }
            }.not_to raise_error
            expect(call_count).to eq(2)
            expect(connection_pool.size).to eq(1)
          end

          expect(connection_pool).to receive(:make_new).once
          connection_pool.hold(:read_only) {}
        end

        context 'with an on_retry callback' do
          it 'calls the callback with the error' do
            callback = double("callback")
            Sequel::ShardedSingleFailoverConnectionPool.register_on_retry_callback callback

            expect(callback).to receive(:call).with(an_instance_of(Sequel::DatabaseDisconnectError), connection_pool)
            call_count = 0
            connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 }
          end
        end

        context 'when in a transaction' do
          it 'raises an exception' do
            allow_any_instance_of(Sequel::Mock::Database).to receive(:in_transaction?).and_return(true)
            expect {
              connection_pool.hold(:read_only) { raise Sequel::DatabaseDisconnectError }
            }.to raise_error(Sequel::DatabaseDisconnectError)
          end
        end
      end
    end

    context 'with default or arbitrary server' do
      it 'does no retry logic and raises error' do
        call_count = 0
        expect {
          connection_pool.hold { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 }
        }.to raise_error(Sequel::DatabaseDisconnectError)
        expect(call_count).to eq(1)
      end
    end
  end

  describe '#failover!' do
    it 'changes failing_over? to true' do
      expect {
        connection_pool.failover!
      }.to change {
        connection_pool.failing_over?
      }.from(false).to(true)
    end
  end

  describe '#reset_retries' do
    it 'calls on_reset callbacks' do
      callback = double(call: true)
      Sequel::ShardedSingleFailoverConnectionPool.register_on_reset_callback callback
      connection_pool.reset_retries(:read_only)
      expect(callback).to have_received(:call).with(connection_pool)
    end

    it 'changes failing_over? to false' do
      connection_pool.failover!
      expect {
        connection_pool.reset_retries(:read_only)
      }.to change {
        connection_pool.failing_over?
      }.from(true).to(false)
    end
  end

  describe '.register_on_retry_callback' do
    it 'adds to the on_retry attribute' do
      callback = Proc.new{ puts "woo" }
      Sequel::ShardedSingleFailoverConnectionPool.register_on_retry_callback callback
      expect(Sequel::ShardedSingleFailoverConnectionPool.on_retry).to eq([callback])
    end
  end

  describe '.register_on_retry_callback' do
    it 'adds to the on_reset attribute' do
      callback = Proc.new{ puts "woo" }
      Sequel::ShardedSingleFailoverConnectionPool.register_on_reset_callback callback
      expect(Sequel::ShardedSingleFailoverConnectionPool.on_reset).to eq([callback])
    end
  end
end
