if {$argc != 2} {error {Usage: vivado -mode batch -source run_sim.tcl -tclargs ip_repository vendor:library:name:version}}
set here [file dirname [file normalize [info script]]]
set ip_repo [file normalize [lindex $argv 0]]
set vlnv [lindex $argv 1]
set build [file join $here simulation]
if {[file exists [file join $build hw2_gpio_sim.xpr]]} {
    error "Simulation project already exists: $build. Preserve it and choose a fresh build directory."
}
create_project hw2_gpio_sim $build -part xc7z020clg484-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property ip_repo_paths [list $ip_repo] [current_project]
update_ip_catalog -rebuild
if {[llength [get_ipdefs -all -filter "VLNV == $vlnv"]] != 1} {error "Packaged IP not found in catalog: $vlnv"}
create_ip -vlnv $vlnv -module_name dut_ip
generate_target all [get_ips dut_ip]
export_ip_user_files -of_objects [get_ips dut_ip] -no_script -sync -force -quiet
add_files -fileset sim_1 -norecurse [file join $here tb_hw2_gpio.sv]
set_property top tb_hw2_gpio [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
set done [get_value -radix unsigned /tb_hw2_gpio/test_done]
set failed [get_value -radix unsigned /tb_hw2_gpio/test_failed]
set assertions [get_value -radix unsigned /tb_hw2_gpio/assertions_passed]
if {$done != 1 || $failed != 0} {error "Packaged IP functional simulation did not pass (done=$done failed=$failed)"}
puts "GPIO_IP_CATALOG_REUSE_SIM_PASS: $assertions assertions"
close_sim
close_project
