#!/usr/bin/env python

import argparse
import serial
import time
import sys
import os
import re
import psutil
import threading

network_line_re = '[a-z0-9]+\s+[0-9]+\s+[a-zA-Z0-9#<>]+\s+[a-f0-9:]+\s+[0-9]\
+\s+[0-9]+\s+([0-9]+)\s+[0-9]+\s+[0-9]+\s+([0-9]+).*'

CMD_OUTPUT_START = 1;
CMD_OUTPUT_STOP = 2;

TYPE_VOLUME = 1;
TYPE_CPU = 2;
TYPE_NETWORK = 3;

CMD_VOLUME_UP = 10;
CMD_VOLUME_DOWN = 11;

last_volume = 0;
last_cpu = 0;
last_net_in = 0;
last_net_out = 0;

def current_net(interface):
  p = os.popen('netstat -ib -I %s' % (interface,))
  lines = p.readlines()
  p.close()
  if len(lines) < 2:
    print('Interface %s not found' % interface)
    return [0, 0]
  line = lines[1]
  m = re.search(network_line_re, line)
  return [int(x) for x in m.groups()]

def current_volume():
  p = os.popen('osascript -e "get volume settings"')
  line = p.readline()
  p.close()
  m = re.search('output volume:([0-9]+),.*', line)
  return int(m.group(1))

def volume_up():
  os.system('osascript -e "set volume output volume %d"' % (
    current_volume() + 10))

def volume_down():
  os.system('osascript -e "set volume output volume %d"' % (
    current_volume() - 10))

def send_output(port, type, value):
  port.write(chr(CMD_OUTPUT_START))
  port.write(chr(type))
  port.write(value)
  port.write(chr(CMD_OUTPUT_STOP))

def send_stats(port, interface, resolution):
  global last_volume, last_cpu, last_net_in, last_net_out
  cpu = str(int(psutil.cpu_percent()))
  volume = str(current_volume())
  net_in, net_out = current_net(interface)
  net_in_diff = net_in - last_net_in
  net_out_diff = net_out - last_net_out
  net_in_per_second = net_in_diff / resolution
  net_out_per_second = net_out_diff / resolution
  last_net_in = net_in
  last_net_out = net_out
   
  network_line = '%dK/%dK' % (
      net_in_per_second / 1024, net_out_per_second / 1024)
  send_output(port, TYPE_NETWORK, network_line)

  if cpu != last_cpu:
    send_output(port, TYPE_CPU, cpu)
    last_cpu = cpu
  if volume != last_volume:
    send_output(port, TYPE_VOLUME, volume)
    last_volume = volume

class Receiver(threading.Thread):
  def __init__(self, port):
    self.port = port
    threading.Thread.__init__(self)
    self.received_kill = False

  def run(self):
    while not self.received_kill:
      incoming = port.read(1)
      if incoming:
        control_code = ord(incoming)
        if(control_code == CMD_VOLUME_UP):
          volume_up()
        elif(control_code == CMD_VOLUME_DOWN):
          volume_down()

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='OSX Dash')
  parser.add_argument('device', type=str, help='Arduino device')
  parser.add_argument('-r', dest='resolution', 
      type=int, help='Resolution in seconds', required=False, default=1)
  parser.add_argument('-n', dest='net', 
      type=str, help='Net device name', required=False, default='en1')
  args = parser.parse_args()
  resolution = args.resolution
  interface = args.net
  port = serial.Serial(args.device, 57600, timeout=1)
  receiver = Receiver(port)
  receiver.start()
  last_net_in, last_net_out = current_net(interface)
  # give the arduino time to start listening
  time.sleep(2)
  while(1):
    try:
      send_stats(port, interface, resolution)
      time.sleep(resolution)
    except KeyboardInterrupt:
      receiver.received_kill = True
      break


