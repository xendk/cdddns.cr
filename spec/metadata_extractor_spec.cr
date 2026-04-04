require "./spec_helper"
require "../src/cdddns/metadata_extractor"

describe Cdddns::MetadataExtractor do
  extractor = Cdddns::MetadataExtractor.new

  it "extracts the default <name>.local hostname" do
    container = Cdddns::Container.new(
      id: "abc",
      name: "/my-container",
      ips: ["172.17.0.2"],
      env: [] of String,
      labels: {} of String => String
    )

    info = extractor.extract(container)
    info.hostnames.should contain("my-container.local")
    info.ips.should eq(["172.17.0.2"])
  end

  it "extracts hostnames from VIRTUAL_HOST env" do
    container = Cdddns::Container.new(
      id: "abc",
      name: "/webapp",
      ips: ["172.17.0.2"],
      env: ["VIRTUAL_HOST=webapp.example.com"],
      labels: {} of String => String
    )

    info = extractor.extract(container)
    info.hostnames.should contain("webapp.example.com")
  end

  it "extracts hostnames from OrbStack labels" do
    container = Cdddns::Container.new(
      id: "abc",
      name: "/orb",
      ips: ["172.17.0.2"],
      env: [] of String,
      labels: {"dev.orbstack.domains" => "custom.local"}
    )

    info = extractor.extract(container)
    info.hostnames.should contain("custom.local")
  end

  it "extracts hostnames from Docker Compose labels" do
    container = Cdddns::Container.new(
      id: "abc",
      name: "/project-db-1",
      ips: ["172.17.0.2"],
      env: [] of String,
      labels: {
        "com.docker.compose.project" => "myproject",
        "com.docker.compose.service" => "db"
      }
    )

    info = extractor.extract(container)
    info.hostnames.should contain("db.myproject.local")
  end

  it "handles multiple IPs and unique hostnames" do
     container = Cdddns::Container.new(
      id: "abc",
      name: "/web",
      ips: ["172.17.0.2", "192.168.0.5", "172.17.0.2"],
      env: ["VIRTUAL_HOST=web.local"],
      labels: {"dev.orbstack.domains" => "web.local"}
    )

    info = extractor.extract(container)
    info.ips.should eq(["172.17.0.2", "192.168.0.5"])
    info.hostnames.should contain("web.local")
    info.hostnames.select { |h| h == "web.local" }.size.should eq(1)
  end
end
