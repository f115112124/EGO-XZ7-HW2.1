# Export matching hardware metadata and bitstream after implementation.
set root [file normalize [file join [file dirname [info script]] ..]]
if {![llength [get_projects -quiet]]} {error "Open hardware/soc_hw2_ip.xpr first."}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Generate Bitstream must finish first."}
file mkdir $root/export $root/reports
open_run impl_1
report_timing_summary -file $root/reports/timing_summary.rpt
report_drc -file $root/reports/drc.rpt
set bit [get_property DIRECTORY [get_runs impl_1]]/design_1_wrapper.bit
if {![file isfile $bit]} {error "No bitstream found. Run Generate Bitstream first."}
file copy -force $bit $root/export/design_1_wrapper.bit
write_hwdef -force $root/export/design_1_wrapper.hwdef
write_sysdef -force -hwdef $root/export/design_1_wrapper.hwdef -bitfile $root/export/design_1_wrapper.bit $root/export/design_1_wrapper.hdf
puts "HW2_IP_EXPORT_OK: $root/export/design_1_wrapper.hdf"
puts "Rebuild SDK for this HDF to refresh paired demo_ip artifacts."
