# Read-only enumeration: no reset, FPGA configuration, or CPU download.
if {[catch {
    connect -url tcp:127.0.0.1:3121
    puts "JTAG_CABLES_BEGIN"
    puts [jtag targets -target-properties -filter {level == 0}]
    puts "JTAG_TARGETS_BEGIN"
    puts [jtag targets -target-properties]
    puts "PROCESSOR_TARGETS_BEGIN"
    puts [targets -target-properties]
    puts "CONNECTION_SCAN_COMPLETE"
    disconnect
} scan_error]} {
    puts "CONNECTION_SCAN_FAILED: $scan_error"
    error $scan_error
}
