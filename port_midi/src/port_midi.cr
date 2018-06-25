require "./port_midi/*"

@[Link("portmidi")]

lib LibPortMidi
  type PmError = Int32
  type PmTimestamp = UInt32

  struct DeviceInfo
    struct_version : Int32      # internal
    interf : UInt8 *            # underlying MIDI API
    name : UInt8 *              # device name
    input : Int32               # true iff input is available
    output : Int32              # true iff output is available
    opened : Int32              # used by generic MidiPort code
  end

  struct Event
    message : UInt32
    imtestamp : Int32
  end

  fun initialize = Pm_Initialize() : PmError

  fun terminate = Pm_Terminate() : PmError

  fun host_error? = Pm_HasHostError(stream : Int64*) : Int32

  fun get_error_text = Pm_GetErrorText(errnum : PmError) : UInt8*

  fun count_devices = Pm_CountDevices() : Int32

  fun get_default_input_device_id = Pm_GetDefaultInputDeviceID() : Int32

  fun get_default_output_device_id = Pm_GetDefaultOutputDeviceID() : Int32

  fun get_device_info = Pm_GetDeviceInfo(device_id : Int32) : DeviceInfo*

  fun open_input = Pm_OpenInput(stream : Int64*, input_device : Int32, input_driver_info : Int32*,
                                buffer_size : Int32, time_proc : Void* -> PmTimestamp,
                                time_info : Void* -> PmTimestamp) : PmError

  fun open_output = Pm_OpenOutput(stream : Int64*, output_device : Int32, output_driver_info : Int32*,
                                  buffer_size : Int32, time_proc : Void* -> PmTimestamp,
                                  time_info : Void* -> PmTimestamp,
                                  latency : Int32) : PmError

  fun set_filter = Pm_SetFilter(stream : Int64*, filters_bitmask : UInt32) : PmError

  fun set_channel_mask = Pm_SetChannelMask(stream : Int64*, bitmask : UInt32) : PmError

  fun abort_write = Pm_Abort(stream : Int64*) : PmError

  fun close_stream = Pm_Close(stream : Int64*) : PmError

  fun synchronize = Pm_Synchronize(stream : Int64*) : PmError

  fun midi_read = Pm_Read(stream : Int64*, buffer : Pointer(Pointer(Event)), length : Int32) : PmError

  fun poll = Pm_Poll(stream : Int64*) : PmError

  fun midi_write = Pm_Write(stream : Int64*, buffer : Event*, length : Int32) : PmError

  fun midi_write_short = Pm_WriteShort(stream : Int64, when_tstamp : Int32, msg : UInt32) : PmError

  fun midi_write_sysex = Pm_WriteSysEx(stream : Int64, when_tstamp : Int32, msg : UInt8*) : PmError
end
