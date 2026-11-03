# Load only this revision's exported bitstream and freshly built application.
# Volatile JTAG programming only. No Flash writes.
set root [file normalize [file join [file dirname [info script]] ..]]
set bit [file join $root demo_ip design_1_wrapper.bit]
set elf [file join $root demo_ip hw2_demo.elf]
set init [file join $root demo_ip ps7_init.tcl]
foreach p [list $bit $elf $init] {if {![file isfile $p]} {error "Missing paired build artifact: $p"}}
connect -url tcp:127.0.0.1:3121
set chips [targets -target-properties -filter {name == "xc7z020"}]
if {[llength $chips] != 1} {puts [targets]; error "Expected one powered EGO-XZ7 on USB-JTAG"}
set cable [dict get [lindex $chips 0] jtag_cable_serial]
targets -set -filter [format {name == "APU" && jtag_cable_serial == "%s"} $cable]
rst -system
after 1000
targets -set -filter [format {name =~ "ARM*#1" && jtag_cable_serial == "%s"} $cable]
catch {stop}
targets -set -filter [format {name =~ "ARM*#0" && jtag_cable_serial == "%s"} $cable]
catch {stop}
source $init
ps7_init
targets -set -filter [format {name == "xc7z020" && jtag_cable_serial == "%s"} $cable]
fpga -file $bit
targets -set -filter [format {name =~ "ARM*#0" && jtag_cable_serial == "%s"} $cable]
ps7_post_config
dow $elf
con
puts "HW2_IP_DEMO_RUNNING: packaged GPIO; count 500 ms; S6 clear and pause 2 s"
disconnect
