# Optional complete rebuild. This does not download to the board.
set script_dir [file dirname [info script]]
source [file join $script_dir create_hardware_project.tcl]
stage "Running synthesis"
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis did not complete"}
stage "Running implementation and bitstream generation"
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation did not complete"}
open_run impl_1
report_timing_summary -file $root/reports/timing_summary.rpt
report_drc -file $root/reports/drc.rpt
report_io -file $root/reports/io.rpt
report_utilization -file $root/reports/utilization.rpt
file copy -force $root/hardware/soc_hw2_ip.runs/impl_1/design_1_wrapper.bit $root/export/design_1_wrapper.bit
write_hwdef -force $root/export/design_1_wrapper.hwdef
write_sysdef -force -hwdef $root/export/design_1_wrapper.hwdef -bitfile $root/export/design_1_wrapper.bit $root/export/design_1_wrapper.hdf
stage "HARDWARE_BUILD_OK"
puts "Project remains open for review."
