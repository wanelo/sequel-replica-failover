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

  @on_retry = []
  @on_reset = []

  class << self
    attr_accessor :on_retry, :on_reset

    def register_on_retry_callback(callback)
      @on_retry << callback
    end

    def clear_on_retry_callbacks
      @on_retry.clear
    end

    def register_on_reset_callback(callback)
      @on_reset << callback
    end

    def clear_on_reset_callbacks
      @on_reset.clear
    end
  end


  # Yields the connection to the supplied block for the given server.
  # This method simulates the ConnectionPool#hold API.
  def hold(server=:default, &block)
    reset_retries(:read_only) if failover_timed_out?(server)

    loop do
      begin
        @response = super(server, &block)
        break
      rescue Sequel::DatabaseDisconnectError, Sequel::DatabaseConnectionError => e
        raise if server != :read_only

        unless self.class.on_retry.empty?
          self.class.on_retry.each { |callback| callback.call(e, self) }
        end

        increment_retries

        if @retry_count >= @pool_retry_count
          reset_retries(server)
          raise
        end
      end
    end

    @response
  end

  def pool_type
    :sharded_single_failover
  end

  def reset_retries(server)
    unless self.class.on_reset.empty?
      self.class.on_reset.each { |callback| callback.call(self) }
    end
    probe(server.to_s) { |p| p.unstick }
    disconnect_server(server)
    @conns[server] = nil
    @failed_at = nil
    @retry_count = nil
  end

  private

  def failover_timed_out?(server)
    server == :read_only &&
      @failed_at &&
      Time.now.to_i - @failed_at.to_i >= @pool_stick_timeout
  end

  def increment_retries
    @retry_count ||= 0
    probe(@retry_count) { |p| p.stick }
    @failed_at ||= Time.now
    @retry_count += 1
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
