require "../../src/cdddns/docker_backend"

module Cdddns
  class MockDockerBackend < DockerBackend
    property containers = {} of String => Container
    property events = [] of DockerEvent

    def listen(&block : DockerEvent ->)
      # Simulates listening by processing the stored events
      events.each do |event|
        yield event
      end
    end

    def inspect_container(id : String) : Container?
      containers[id]?
    end

    def list_containers : Array(Container)
      containers.values
    end

    def add_container(container : Container)
      containers[container.id] = container
    end

    def emit_event(type : String, action : String, id : String, attributes = {} of String => String)
      event_json = {
        "Type" => type,
        "Action" => action,
        "Actor" => {
          "ID" => id,
          "Attributes" => attributes
        }
      }.to_json
      events << DockerEvent.from_json(event_json)
    end
  end
end
