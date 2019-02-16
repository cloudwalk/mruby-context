class ThreadScheduler
  THREAD_STATUS_BAR    = 0
  THREAD_COMMUNICATION = 1

  class << self
    attr_accessor :status_bar, :communication, :cache
  end
  self.cache = Hash.new

  def self.start
    self.spawn_status_bar
    self.spawn_communication
  end

  def self.stop
    stop_status_bar
    stop_communication
  end

  def self.keep_alive
    self.spawn_communication if self.die?(:communication)
    self.spawn_status_bar if self.die?(:status_bar)
  end

  def self.spawn_status_bar
    if DaFunk::Helper::StatusBar.valid?
      _start(THREAD_STATUS_BAR)
      str = "Context.start('main', '#{Device.adapter}', '{\"initialize\":\"status_bar\"}')"
      self.status_bar = Thread.new do
        mrb_eval(str)
        _stop(THREAD_STATUS_BAR)
      end
    end
  end

  def self.stop_status_bar
    if self.status_bar
      _stop(THREAD_STATUS_BAR)
      self.status_bar.join
      self.status_bar = nil
    end
  end

  def self.spawn_communication
    _start(THREAD_COMMUNICATION)
    str = "Context.start('main', '#{Device.adapter}', '{\"initialize\":\"communication\"}')"
    self.communication = Thread.new do
      mrb_eval(str)
      _stop(THREAD_COMMUNICATION)
    end
  end

  def self.stop_communication
    if self.communication
      _stop(THREAD_COMMUNICATION)
      self.communication.join
      self.communication = nil
    end
  end

  def self.command(id, string)
    self.cache[id] ||= {}

    value = ThreadScheduler._command(id, string)
    if value != "cache"
      self.cache[id][string] = eval(value)
    else
      self.cache[id][string] ||= false
    end
  end

  def self.execute(id)
    self._execute(id) do |str|
      begin
        if str == "connect"
          (!! DaFunk::PaymentChannel.connect(false)).to_s
        else
          if DaFunk::PaymentChannel.client
            if str == "check"
              DaFunk::PaymentChannel.client.check(false).to_s
            else
              DaFunk::PaymentChannel.client.send(str).to_s
            end
          else
            "false"
          end
        end
      rescue => e
        ContextLog.exception(e, e.backtrace, "Thread [#{id}] execution error")
        "cache"
      end
    end
  end

  def self.alive?(thread)
    check(thread) == :alive
  end

  def self.die?(thread)
    check(thread) == :dead
  end

  def self.pause?(thread)
    check(thread) == :pause
  end

  def self.pause!(thread)
    _pause(thread)
  end

  def self.continue!(thread)
    _continue(thread)
  end

  def self.communication_thread?
    DaFunk::PaymentChannel.client != Context::CommunicationChannel
  end

  def self.pausing_communication(&block)
    Context::ThreadPubSub.publish("communication_update")
    if ! self.communication_thread?
      pausing(ThreadScheduler::THREAD_COMMUNICATION, &block)
    else
      block.call
    end
  ensure
    Context::ThreadPubSub.publish("communication_update")
  end

  def self.pausing(thread, &block)
    pause!(thread)
    block.call
  ensure
    continue!(thread)
  end

  def self.check(thread)
    case thread
    when :status_bar
      _parse(_check(THREAD_STATUS_BAR))
    when :communication
      _parse(_check(THREAD_COMMUNICATION))
    else
      _parse(_check(THREAD_STATUS_BAR))
    end
  end

  def self._parse(status)
    case status
    when 0
      :dead
    when 1
      :alive
    when 2
      :alive
    when 3
      :alive
    when 4
      :pause
    else
      :dead
    end
  end
end

