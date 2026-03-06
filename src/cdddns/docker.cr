require "http/client"
require "socket"
require "json"
require "uri"

module Cdddns
  # With thanks to @jgaskins
  module Docker
    struct Event
      include JSON::Serializable

      @[JSON::Field(key: "Type")]
      getter type : String
      @[JSON::Field(key: "Action")]
      getter action : String
      @[JSON::Field(key: "Actor")]
      getter actor : Actor
      getter scope : String
      @[JSON::Field(key: "timeNano", converter: Time::EpochNanosConverter)]
      getter time : Time

      struct Actor
        include JSON::Serializable

        @[JSON::Field(key: "ID")]
        getter id : String
        @[JSON::Field(key: "Attributes")]
        getter attributes : Hash(String, String)
      end
    end

    def self.listen
      socket_path = ENV.fetch("DOCKER_HOST", "/var/run/docker.sock").lchop("unix://")
      log = Log.for("docker")

      UNIXSocket.open socket_path do |socket|
        http = HTTP::Client.new(socket)
        # TODO figure out filters.
        filters = URI.encode_www_form("")

        log.notice &.emit "Listening for Docker events", socket: socket_path
        http.get("/events?#{filters}") do |response|
          unless response.status.success?
            STDERR.puts "Error: #{response.status} – #{response.body_io.gets_to_end}"
            exit 1
          end

          response.body_io.each_line do |line|
            next if line.blank?

            event = Event.from_json(line)
            # log.info &.emit event.type,
            #                 action: event.action,
            #                 image: event.actor.attributes["image"]?.to_s
            yield event
            # Do something with the event
          end
        end
      end
    end
  end
end

module Time::EpochNanosConverter
  extend self

  def from_json(json : JSON::PullParser)
    Time::UNIX_EPOCH + json.read_int.nanoseconds
  end
end
