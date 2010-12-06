#!/bin/env ruby
require 'rubygems'
require 'msgpack/rpc'

class BulkServer
  def initialize
    @data = ""
    @megabyte = Array.new(1024*1024).map{rand(256)}.pack("C*")
  end

  def prepare_data(size_megabyte)
    @data = @megabyte * size_megabyte
    return nil
  end

  def get_data_dup
    return @data.dup
  end

  def get_data
    return @data
  end

  def do_GC
    GC.start
  end

end

class BulkServer_MPRPC
  def initialize(ipaddr="127.0.0.1", port=12345)
    @bulkserver = BulkServer.new

    @mpserver = MessagePack::RPC::Server.new
    @mpserver.listen(ipaddr, port, @bulkserver)
    @mpserver.run
  end
end

if $0 == __FILE__
  ipaddr = "0.0.0.0"
  port   = 12345

  puts "listen: #{ipaddr}:#{port}"
  GC.disable
  server = BulkServer_MPRPC.new(ipaddr, port)
end
