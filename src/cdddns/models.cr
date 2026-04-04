require "json"

module Cdddns
  record HostInfo,
    hostnames : Array(String),
    ips : Array(String)

  struct DockerEvent
    include JSON::Serializable

    @[JSON::Field(key: "Type")]
    getter type : String

    @[JSON::Field(key: "Action")]
    getter action : String

    @[JSON::Field(key: "Actor")]
    getter actor : Actor

    struct Actor
      include JSON::Serializable

      @[JSON::Field(key: "ID")]
      getter id : String

      @[JSON::Field(key: "Attributes")]
      getter attributes : Hash(String, String)
    end
  end

  struct Container
    property id : String
    property name : String
    property ips : Array(String)
    property env : Array(String)
    property labels : Hash(String, String)

    def initialize(@id, @name, @ips, @env, @labels)
    end
  end
end
