require "./models"
require "./metadata_extractor"
require "./hosts_manager"
require "./docker_backend"

module Cdddns
  class Daemon
    def initialize(
      @backend : DockerBackend,
      @extractor : MetadataExtractor,
      @manager : HostsManager
    )
      @addresses = {} of String => HostInfo
    end

    def run
      sync_initial_state
      update_hosts
      
      @backend.listen do |event|
        handle_event(event)
      end
    end

    def sync_initial_state
      @backend.list_containers.each do |container|
        next if is_oneoff?(container)
        @addresses[container.id] = @extractor.extract(container)
      end
    end

    def handle_event(event : DockerEvent)
      return unless event.type == "container"
      return if event.actor.attributes["com.docker.compose.oneoff"]? == "True"

      case event.action
      when "start"
        if container = @backend.inspect_container(event.actor.id)
          @addresses[event.actor.id] = @extractor.extract(container)
          update_hosts
        end
      when "die", "kill", "pause"
        if @addresses.delete(event.actor.id)
          update_hosts
        end
      end
    end

    private def is_oneoff?(container : Container)
      container.labels["com.docker.compose.oneoff"]? == "True"
    end

    private def update_hosts
      @manager.update(@addresses.values)
    end
  end
end
