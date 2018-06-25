require "port_midi"

def list_devices(title : String, devices : Hash(Int32, LibPortMidi::DeviceInfo))
  puts title
  devices.each do |index, dev|
    puts "  #{index}: #{String.new(dev.name)}#{dev.opened == 1 ? " (open)" : ""}"
  end
end

LibPortMidi.initialize()
num_devices = LibPortMidi.count_devices
puts "there are #{num_devices} devices"
inputs = {} of Int32 => LibPortMidi::DeviceInfo
outputs = {} of Int32 => LibPortMidi::DeviceInfo
(0...num_devices).each do |i|
  device = LibPortMidi.get_device_info(i).value
  if device.input != 0
    inputs[i] = device
  end
  if device.output != 0
    outputs[i] = device
  end
end
list_devices("Inputs", inputs)
list_devices("Outputs", outputs)
LibPortMidi.terminate()
