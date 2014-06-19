require 'sequel'
require 'sequel/connection_pool/sharded_single'

class Sequel::ShardedSingleFailoverConnectionPool < Sequel::ShardedSingleConnectionPool
  attr_accessor :failing_over

  def initialize(db, opts = OPTS)
    super
    @pool_stick_timeout = opts[:pool_stick_timeout] || 15
    @pool_retry_count = opts[:pool_retry_count] || 5
    @failing_over = false
  end

  @on_disconnect = []
  @on_unstick = []

  class << self
    attr_accessor :on_disconnect, :on_unstick

    def register_on_disconnect_callback(callback)
      @on_disconnect << callback
    end

    def clear_on_disconnect_callbacks
      @on_disconnect.clear
    end

    def register_on_unstick_callback(callback)
      @on_unstick << callback
    end

    def clear_on_unstick_callbacks
      @on_unstick.clear
    end
  end


  # Yields the connection to the supplied block for the given server.
  # This method simulates the ConnectionPool#hold API.
  def hold(server=:default, &block)
    unstick(:read_only) if failover_timed_out?(server)

    loop do
      begin
        @response = super(server, &block)
        break
      rescue Sequel::DatabaseDisconnectError, Sequel::DatabaseConnectionError => e
        raise if server != :read_only

        unless self.class.on_disconnect.empty?
          self.class.on_disconnect.each { |callback| callback.call(e, self) }
        end

        stick

        if @stuck_times >= @pool_retry_count
          unstick(server)
          raise
        end
      end
    end

    @response
  end

  def pool_type
    :sharded_single_failover
  end

  def unstick(server)
    unless self.class.on_unstick.empty?
      self.class.on_unstick.each { |callback| callback.call(self) }
    end
    probe(server.to_s) { |p| p.unstick }
    disconnect_server(server)
    @conns[server] = nil
    @stuck_at = nil
    @stuck_times = nil
  end

  private

  def failover_timed_out?(server)
    server == :read_only &&
      @stuck_at &&
      Time.now.to_i - @stuck_at.to_i >= @pool_stick_timeout
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
