require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

module Beetle
  class ConfiguratorTest < Test::Unit::TestCase

    def setup
      Configurator.active_master = nil
      dumb_client = Client.new
      dumb_client.stubs(:publish)
      dumb_client.stubs(:subscribe)
      Configurator.client = dumb_client
      Configurator.stubs(:setup_propose_check_timer)
      @configurator = Configurator.new
      Configurator.client.deduplication_store.redis_instances = []
    end

    test "process should forward to class methods" do
      message = mock('message', :data => '{"op":"give_master", "somevariable": "somevalue"}')
      @configurator.stubs(:message).returns(message)
      Configurator.expects(:give_master).with({"somevariable" => "somevalue"})
      @configurator.process()
    end

    test "find_active_master should return if the current active_master if it is still active set" do
      first_working_redis      = redis_stub('redis1')
      first_working_redis.expects(:info).never
      second_working_redis     = redis_stub('redis2', :info => 'ok')

      Configurator.client.deduplication_store.redis_instances = [first_working_redis, second_working_redis]
      Configurator.active_master = second_working_redis
      Configurator.find_active_master
      assert_equal second_working_redis, Configurator.active_master
    end

    test "find_active_master should retry to reach the current master if it doesn't respond" do
      redis = redis_stub('redis')
      redis.expects(:info).times(2).raises(Timeout::Error).then.returns('ok')
      Beetle.config.redis_watcher_retry_timeout = 0.second
      Beetle.config.redis_watcher_retries       = 1
      Configurator.client.deduplication_store.redis_instances = [redis]
      Configurator.active_master = redis
      Configurator.find_active_master
      assert_equal redis, Configurator.active_master
    end

    test "find_active_master should finally give up to reach the current master after the max timeouts have been reached" do
      non_working_redis  = redis_stub('non-working-redis')
      non_working_redis.expects(:info).raises(Timeout::Error).twice
      working_redis      = redis_stub('working-redis')
      working_redis.expects(:info).returns("ok")

      Beetle.config.redis_watcher_retry_timeout   = 0.second
      Beetle.config.redis_watcher_retries         = 1
      Configurator.client.deduplication_store.redis_instances = [non_working_redis, working_redis]
      Configurator.active_master = non_working_redis
      Configurator.find_active_master
    end

    test "find_active_master should propose the first redis it consideres as working" do
      Configurator.active_master = nil
      working_redis = redis_stub('working-redis', :info => "ok")
      Configurator.client.deduplication_store.redis_instances = [working_redis]
      Configurator.expects(:propose).with(working_redis)
      Configurator.find_active_master
    end

    test "the current master should be set to nil during the proposal phase" do
      Configurator.expects(:clear_active_master)
      Configurator.propose(redis_stub('new_master'))
    end

    test "clear active master should set the current master to nil" do
      Configurator.active_master = "snafu"
      Configurator.send(:clear_active_master)
      assert_nil Configurator.active_master
    end

    test "proposing a new master should publish the master to the system queue" do
      host = "my_host"
      port = "my_port"
      payload = {:host => host, :port => port}
      new_master = redis_stub("new_master", payload)
      Configurator.client.expects(:publish) do |json|
        ActiveSupport::JSON.decode(json) == payload
      end
      Configurator.propose(new_master)
    end

    test "give master should return the current master" do
    end

    test "proposing a new master should set the current master to nil" do
    end

    test "proposing a new master should wait for a response of every known server" do
    end

    test "proposing a new master should fail unless every known server respondes with an acknowledgement" do
    end

    test "proposing a new master should give the order to reconfigure if every server accepted the proposal" do
    end

    test "proposing a new master should wait for the reconfigured message from every known server after giving the order to reconfigure" do
    end

    private
    def redis_stub(name, opts = {:host => "foo", :port => 123})
      stub(name, opts)
    end
  end
end