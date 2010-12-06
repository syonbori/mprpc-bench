#!/bin/env ruby
require 'rubygems'
require 'msgpack/rpc'
require 'date'
require 'thread'
require './mprpc-server'

sizes     = [1, 2, 4, 8, 16, 32, 64, 128]
ipaddr    = ARGV[0] || "127.0.0.1"
port      = (ARGV[1]==nil) ? 12345 : ARGV[1].to_i
try_count = (ARGV[2]==nil) ? 5 : ARGV[2].to_i

def bench(size, try_count = 1)
  diff_ary = Array.new(try_count).map{
    before = Time.now
    yield
    diff_sec = Time.now - before
  }

  sum = 0.0
  diff_ary.each{|d| sum+=d}
  avg_time = sum / try_count

  div = 0.0
  diff_ary.each{|d| div+=(d-avg_time)*(d-avg_time)}
  div = Math.sqrt(div / try_count)

  printf("%7s %10.8f (%8.3f MBps, std-dev=%6.4f, %d trials)\n",
         "#{size}MB",
         avg_time,
         size / avg_time,
         div,
         try_count)
end


puts "********** Local Call *********"
server_wo_rpc = BulkServer.new

sizes.each do |size|
  GC.start
  server_wo_rpc.prepare_data(size)
  bench(size, try_count){ server_wo_rpc.get_data_dup }
end

puts

puts "********** Sync RPC ********** "
mpclient = MessagePack::RPC::Client.new(ipaddr, port)
mpclient.timeout = 10
mpclient.call(:do_GC)

sizes.each do |size|
  GC.start
  mpclient.call(:prepare_data, size)
  bench(size, try_count){ mpclient.call(:get_data) }
end

puts

puts "********** Async RPC (Overhead of async&Future.get) ********** "
mpclient = MessagePack::RPC::Client.new(ipaddr, port)
mpclient.timeout = 10
mpclient.call(:do_GC)

sizes.each do |size|
  GC.start
  mpclient.call(:prepare_data, size)
  bench(size, try_count){
    f = mpclient.call_async(:get_data)
    f.get
  }
end

puts

puts "********** Async map RPC ********** "
mpclient = MessagePack::RPC::Client.new(ipaddr, port)
mpclient.timeout = 10
mpclient.call(:do_GC)

sizes.each do |size|
  GC.start
  mpclient.call(:prepare_data, 1) # server responds 1MiB data

  bench(size, try_count){
    ret_array = Array.new(size).map{
      mpclient.call_async(:get_data)
    }.map{|f|
      f.get
    }

    ret_array.join
  }
end

puts

puts "********** Sync, threaded  RPC ********** "
mpclients = Array.new(128).map{c=MessagePack::RPC::Client.new(ipaddr, port); c.timeout=10; c}
mpclients[0].call(:do_GC)

sizes.each do |size|
  GC.start
  mpclients[0].call(:prepare_data, 1) # server responds 1MiB data

  bench(size, try_count){
    ret_array = Array.new(size)
    threads = Array.new(size)
    size.times do |idx|
      threads[idx] = Thread.new(idx){
        ret_array[idx] = mpclients[idx].call(:get_data)
      }
    end
    threads.each{|t| t.join}

    ret_array.join
  }
end

puts
