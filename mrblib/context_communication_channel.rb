class Context
  class CommunicationChannel
    THREAD_COMMUNICATION = 1

    class << self
      attr_accessor :boot_time, :booting
    end

    self.boot_time = Time.now
    self.booting   = true

    def initialize(client = nil)
    end

    def self.booting?
      if self.booting
        if (self.boot_time + 180) < Time.now
          self.booting = false
        end
      end
      self.booting
    end

    def self.client
      true
    end

    def self.write(value)
      ThreadChannel.channel_write(THREAD_COMMUNICATION, value)
    end

    def self.read
      ThreadChannel.channel_read(THREAD_COMMUNICATION)
    end

    def self.close
      ThreadScheduler.cache_clear!
      ThreadScheduler.command(THREAD_COMMUNICATION, "close")
    end

    def self.connected?
      ThreadScheduler.command(THREAD_COMMUNICATION, "connected?")
    end

    def self.handshake?
      if self.connected?
        timeout = Time.now + Device::Setting.tcp_recv_timeout.to_i
        loop do
          break(true) if ThreadScheduler.command(THREAD_COMMUNICATION, "handshake?")
          break if Time.now > timeout || getc(200) == Device::IO::CANCEL
        end
      end
    end

    def self.handshake
      ThreadScheduler.command(THREAD_COMMUNICATION, "handshake")
    end

    def self.connect(options = nil)
      if ThreadScheduler.command(THREAD_COMMUNICATION, "connect")
        self
      end
    end

    def self.handshake_response
      if DaFunk::ParamsDat.file["access_token"]
        {"token" => DaFunk::ParamsDat.file["access_token"]}.to_json
      end
    end

    def self.check
      if Device::Network.connected? && self.connected? && self.handshake?
        message = self.read
      end
      if message.nil? && DaFunk::ConnectionManagement.primary_try?
        return :primary_communication
      end
      message
    end
  end
end
