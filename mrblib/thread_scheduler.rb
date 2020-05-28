class ThreadScheduler
  class ThreadSchedulerNotFoundError < StandardError; end

  THREAD_EXTERNAL_STATUS_BAR    = :status_bar
  THREAD_EXTERNAL_COMMUNICATION = :communication
  THREAD_INTERNAL_STATUS_BAR    = 0
  THREAD_INTERNAL_COMMUNICATION = 1

  EXTERNAL_TO_INTERNAL = {
    THREAD_EXTERNAL_STATUS_BAR    => THREAD_INTERNAL_STATUS_BAR,
    THREAD_EXTERNAL_COMMUNICATION => THREAD_INTERNAL_COMMUNICATION
  }

  INTERNAL_TO_EXTERNAL = EXTERNAL_TO_INTERNAL.invert
  NOT_CACHEABLE = ["code"]

  class << self
    attr_accessor :status_bar, :communication, :cache
  end
  self.cache = Hash.new

  def self.start
    self.spawn_communication
  end

  def self.stop
    stop_communication
  end

  def self.cache_clear!
    self.cache = Hash.new
  end

  def self.keep_alive
    self.spawn_communication if self.die?(:communication)
  end

  def self.spawn_communication
    _start(THREAD_INTERNAL_COMMUNICATION)
    str = "Context.start('main', '#{Device.adapter}'); "
    str << "Context.execute('main', '#{Device.adapter}', '{\"initialize\":\"communication\"}')"
    self.communication = Thread.new do
      mrb_eval(str, 'thread_communication')
      _stop(THREAD_INTERNAL_COMMUNICATION)
    end
  end

  def self.stop_communication
    if self.communication
      _stop(THREAD_INTERNAL_COMMUNICATION)
      self.communication.join
      self.communication = nil
    end
  end

  def self.command(thread, string, value = nil)
    id = EXTERNAL_TO_INTERNAL[thread]
    self.cache[id] ||= {}

    buffer = value ? "#{string}=#{value}" : string
    result = self._command(id, buffer)
    if NOT_CACHEABLE.include?(string)
      return eval(result == 'cache' ? 'nil' : result)
    end

    if result != "cache"
      self.cache[id][string] = eval(result)
    else
      self.cache[id][string] ||= nil
    end
  end

  # TODO Refactor to send mruby irep binary
  def self.execute(thread)
    id = EXTERNAL_TO_INTERNAL[thread]
    self._execute(id) do |str|
      begin
        if str == "connect"
          (!! DaFunk::PaymentChannel.connect(false)).to_s
        elsif str.include?("=")
          method, value = str.split("=")
          DaFunk::PaymentChannel.send("#{method}=", value)
          "true"
        elsif str == 'check'
          self.payment_channel&.check(false).to_s
        else
          self.payment_channel&.send(str).to_s
        end
      rescue => e
        ContextLog.exception(e, e.backtrace, "Thread [#{id}] execution error")
        "cache"
      end
    end
  end

  def self.payment_channel
    if DaFunk::PaymentChannel.respond_to? :current
      DaFunk::PaymentChannel.current
    else
      DaFunk::PaymentChannel.client
    end
  end

  def self.alive?(thread)
    check(thread) == :alive
  end

  def self.die?(thread)
    check(thread) == :dead
  end

  def self.pause?(thread, timeout = 0)
    status = check(thread, timeout)
    status == :pause || status == :block
  end

  def self.pause!(thread)
    _pause(EXTERNAL_TO_INTERNAL[thread])
  end

  def self.continue!(thread)
    _continue(EXTERNAL_TO_INTERNAL[thread])
  end

  def self.communication_thread?
    self.payment_channel != Context::CommunicationChannel
  end

  def self.pausing_communication(&block)
    if ! self.communication_thread?
      pausing(THREAD_EXTERNAL_COMMUNICATION, &block)
    else
      block.call
    end
  end

  def self.pausing(thread, &block)
    ret = pause!(thread)
    block.call
  ensure
    continue!(thread)
  end

  def self.check(thread, timeout = 0)
    case thread
    when :status_bar
      if DaFunk::Helper::StatusBar.valid?
        _parse(_check(THREAD_INTERNAL_STATUS_BAR, timeout))
      end
    when :communication
      _parse(_check(THREAD_INTERNAL_COMMUNICATION, timeout))
    else
      raise ThreadScheduler::ThreadSchedulerNotFoundError.new("Thread '#{thread}' not found on check")
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
    when 5
      :block
    else
      :dead
    end
  end
end

class Context
  ThreadScheduler = ::ThreadScheduler
end

