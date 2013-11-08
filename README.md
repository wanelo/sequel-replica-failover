# Automatic read-only failover for Sequel

[![Code Climate](https://codeclimate.com/github/wanelo/sequel-replica-failover.png)](https://codeclimate.com/github/wanelo/sequel-replica-failover)

This provides a NOT-THREADSAFE sharded connection pool for failing over between configured replicas.

The mechanisms it provides are as follows:

1. When a DatabaseDisconnectError or DatabaseConnectError occurs, the pool attempt to make another connection to the
   :read_only server and retry.
2. The pool will retry `:pool_retry_count` times afterwhich it will raise the exception that triggered the failover.
3. The pool will stick to a working connection for `:pool_stick_timeout` (in seconds) after which it will
   try connecting back to a replica.
4. Anytime a transaction has been started, the pool will NOT failover.

## Installation

Add this line to your application's Gemfile:

    gem 'sequel-replica-failover'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sequel-replica-failover

## Usage

When initializing a Sequel connection, set the pool class:

```ruby
DB = Sequel.connect({
                      :adapter => 'postgres',
                      :user => 'postgres',
                      :password => 'postgres',
                      :host => '127.0.0.1',
                      :database => 'postgres',
                      :port => 5432,
                      :pool_class => Sequel::ShardedSingleFailoverConnectionPool,
                      :pool_retry_count => 10,
                      :pool_stick_timeout => 30
                    })
```



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
