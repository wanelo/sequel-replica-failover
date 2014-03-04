require 'spec_helper'
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

describe Sequel::ShardedSingleFailoverConnectionPool do
  describe '#hold' do
    before do
      msp = proc { @max_size=3 }
      @connection_pool = Sequel::ConnectionPool.get_pool(mock_db.call(proc { |c| msp.call }) { :got_connection }, CONNECTION_POOL_DEFAULTS)
    end

    context 'with read_only server' do
      context 'when block raises a database connection error' do
        it 'retries until the a successful connection is made' do
          call_count = 0
          proc { @connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 } }.should_not raise_error
          expect(call_count).to eq(2)
        end

        it 'only retries N number of times before actually raising the error' do
          call_count = 0
          proc { @connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError } }.should raise_error(Sequel::DatabaseDisconnectError)
          expect(call_count).to eq(3)
        end

        it 'sticks for N number of seconds to a working connection' do
          Timecop.freeze -16 do
            call_count = 0
            proc { @connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 } }.should_not raise_error
            expect(call_count).to eq(2)
            expect(@connection_pool.size).to eq(1)
          end

          @connection_pool.should_receive(:make_new).once
          @connection_pool.hold(:read_only) {}
        end

        context 'with an on_disconnect callback' do
          it 'calls the callback with the error' do
            callback = double("callback")
            Sequel::ShardedSingleFailoverConnectionPool.on_disconnect = callback

            expect(callback).to receive(:call).with(an_instance_of(Sequel::DatabaseDisconnectError), @connection_pool)
            call_count = 0
            @connection_pool.hold(:read_only) { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 }
          end
        end

        context 'when in a transaction' do
          it 'raises an exception' do
            Sequel::Mock::Database.any_instance.should_receive(:in_transaction?).and_return(true)
            proc { @connection_pool.hold(:read_only) { raise Sequel::DatabaseDisconnectError } }.should raise_error(Sequel::DatabaseDisconnectError)
          end
        end
      end
    end

    context 'with default or arbritrary server' do
      it 'does no retry logic and raises error' do
        call_count = 0
        proc { @connection_pool.hold { call_count += 1; raise Sequel::DatabaseDisconnectError if call_count == 1 } }.should raise_error(Sequel::DatabaseDisconnectError)
        expect(call_count).to eq(1)
      end
    end
  end

  describe '.on_disconnect' do
    it 'sets the on_disconnect attribute' do
      callback = Proc.new{ puts "woo" }
      Sequel::ShardedSingleFailoverConnectionPool.on_disconnect = callback
      expect(Sequel::ShardedSingleFailoverConnectionPool.on_disconnect).to eq(callback)
    end
  end
end
