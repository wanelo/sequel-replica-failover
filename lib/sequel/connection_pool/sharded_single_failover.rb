require 'sequel'
require 'sequel/connection_pool/sharded_single'

class Sequel::ShardedSingleFailoverConnectionPool < Sequel::ShardedSingleConnectionPool
  def initialize(db, opts = OPTS)
    super
    @pool_stick_timeout = opts[:pool_stick_timeout] || 15
    @pool_retry_count   = opts[:pool_retry_count]   || 5
  end

  # Yields the connection to the supplied block for the given server.
  # This method simulates the ConnectionPool#hold API.
  def hold(server=:default, &block)
    if server == :read_only &&
       @stuck_at &&
       Time.now.to_i - @stuck_at.to_i >= @pool_stick_timeout
      unstick(:read_only)
    end

    super(server, &block)
  rescue Sequel::DatabaseDisconnectError, Sequel::DatabaseConnectionError
    if server == :read_only && !@db.in_transaction?(server: :read_only)
      disconnect_server(server)
      @conns[server] = nil

      stick

      if @stuck_times >= @pool_retry_count
        unstick(server)
        raise
      end

      hold(server, &block)
    else
      raise
    end
  end

  def pool_type
    :sharded_single_failover
  end

  private

  def unstick(server)
    probe(server.to_s) { |p| p.unstick }
    disconnect_server(server)
    @conns[server] = nil
    @stuck_at = nil
    @stuck_times = nil
  end

  def stick
    @stuck_times ||= 0
    probe(@stuck_times) { |p| p.stick }
    @stuck_at ||= Time.now
    @stuck_times += 1
  end

  def probe(*args)
    p = yield(Sequel::ReplicaFailover::DTraceProvider.provider)
    return unless p.enabled?
    if args.any?
      p.fire(*args)
    else
      p.fire
    end
  end
end
