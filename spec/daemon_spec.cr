require "./spec_helper"
require "./mocks/docker_backend"
require "../src/cdddns/daemon"

class TestHostsManager < Cdddns::HostsManager
  def initialize(@output : IO::Memory)
    super("/tmp/unused")
  end
  
  def update(hosts : Array(Cdddns::HostInfo))
    @output.clear
    process_update(IO::Memory.new, @output, generate_fragment(hosts))
  end
end

describe Cdddns::Daemon do
  it "syncs initial state and updates hosts file" do
    backend = Cdddns::MockDockerBackend.new
    extractor = Cdddns::MetadataExtractor.new
    output = IO::Memory.new
    manager = TestHostsManager.new(output)
    
    container1 = Cdddns::Container.new(
      id: "abc",
      name: "/web",
      ips: ["1.1.1.1"],
      env: [] of String,
      labels: {} of String => String
    )
    backend.add_container(container1)
    
    daemon = Cdddns::Daemon.new(backend, extractor, manager)
    daemon.sync_initial_state
    daemon.run # This will trigger sync, update, and then mock-listen
    
    output.to_s.should contain("1.1.1.1\tweb.local\n")
  end

  it "handles container events" do
    backend = Cdddns::MockDockerBackend.new
    extractor = Cdddns::MetadataExtractor.new
    output = IO::Memory.new
    manager = TestHostsManager.new(output)
    
    daemon = Cdddns::Daemon.new(backend, extractor, manager)
    
    # Simulate a container starting
    container = Cdddns::Container.new(
      id: "123",
      name: "/new-db",
      ips: ["2.2.2.2"],
      env: [] of String,
      labels: {} of String => String
    )
    backend.add_container(container)
    
    # Emit start event
    backend.emit_event("container", "start", "123")
    
    # Manually trigger listening loop (in our mock)
    backend.listen do |event|
      daemon.handle_event(event)
    end
    
    output.to_s.should contain("2.2.2.2\tnew-db.local\n")
    
    # Emit die event
    backend.events.clear
    backend.emit_event("container", "die", "123")
    
    backend.listen do |event|
      daemon.handle_event(event)
    end
    
    # If fragment is empty and input was empty, nothing is written (which is fine)
    output.to_s.should be_empty
  end
end
