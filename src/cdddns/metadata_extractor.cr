require "./models"

module Cdddns
  class MetadataExtractor
    def extract(container : Container) : HostInfo
      hostnames = [] of String
      ips = container.ips

      # <containername>.local
      # container.name usually starts with "/"
      name = container.name.lchop('/')
      hostnames << "#{name}.local"

      # Get name from VIRTUAL_HOST env variable.
      container.env.each do |env_def|
        if env_def =~ /^VIRTUAL_HOST=(.*)/
          hostnames << $~[1]
        end
      end

      # Use orbstacks label.
      if name = container.labels["dev.orbstack.domains"]?
        hostnames << name
      end

      compose_project = container.labels["com.docker.compose.project"]?
      compose_service = container.labels["com.docker.compose.service"]?

      # Docker Compose <service>.<compose_project>.local
      if compose_project && compose_service
        hostnames << "#{compose_service}.#{compose_project}.local"
      end

      HostInfo.new(hostnames: hostnames.uniq, ips: ips.uniq)
    end
  end
end
