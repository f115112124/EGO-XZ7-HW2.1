# Vivado 2018.3: package the LED/button GPIO subsystem as a reusable IP.
# Project layout: scripts/package_gpio_ip.tcl and ip_repo/hw2_gpio_ip_1_0.
# Optional -tclargs <new-output-directory> selects a staging destination.
set project_root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]]} {
    error "Close the current project before packaging, or run a fresh Vivado batch process."
}
if {[info exists argv] && [llength $argv] > 0} {
    set ip_dir [file normalize [lindex $argv 0]]
} else {
    set ip_dir [file join $project_root ip_repo hw2_gpio_ip_1_0]
}
if {[file exists $ip_dir]} {
    error "Refusing to overwrite existing IP directory: $ip_dir. Select a new staging output with -tclargs <new-output-directory>."
}
set build_dir [file join $project_root .ip_packaging_work run_[clock seconds]]
file mkdir [file dirname $ip_dir]
create_project gpio_package $build_dir -part xc7z020clg484-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
create_bd_design gpio_subsystem
set axi [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI]
set_property -dict [list CONFIG.PROTOCOL AXI4LITE CONFIG.DATA_WIDTH 32 CONFIG.ADDR_WIDTH 17 CONFIG.FREQ_HZ 50000000] $axi
set clk [create_bd_port -dir I -type clk s_axi_aclk]
set_property -dict [list CONFIG.FREQ_HZ 50000000 CONFIG.ASSOCIATED_BUSIF S_AXI CONFIG.ASSOCIATED_RESET s_axi_aresetn] $clk
set rst [create_bd_port -dir I -type rst s_axi_aresetn]
set_property CONFIG.POLARITY ACTIVE_LOW $rst
create_bd_port -dir O -from 7 -to 0 led_o
create_bd_port -dir I -from 4 -to 0 btn_i
create_bd_port -dir O -type intr irq
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 led_gpio
set_property -dict [list CONFIG.C_GPIO_WIDTH 8 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_ALL_INPUTS 0 CONFIG.C_IS_DUAL 0 CONFIG.C_INTERRUPT_PRESENT 0 CONFIG.USE_BOARD_FLOW false] [get_bd_cells led_gpio]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 button_gpio
set_property -dict [list CONFIG.C_GPIO_WIDTH 5 CONFIG.C_ALL_INPUTS 1 CONFIG.C_ALL_OUTPUTS 0 CONFIG.C_IS_DUAL 0 CONFIG.C_INTERRUPT_PRESENT 1 CONFIG.USE_BOARD_FLOW false] [get_bd_cells button_gpio]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_periph
set_property -dict [list CONFIG.NUM_SI 1 CONFIG.NUM_MI 2] [get_bd_cells axi_periph]
connect_bd_intf_net [get_bd_intf_ports S_AXI] [get_bd_intf_pins axi_periph/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_periph/M00_AXI] [get_bd_intf_pins led_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_periph/M01_AXI] [get_bd_intf_pins button_gpio/S_AXI]
connect_bd_net [get_bd_ports s_axi_aclk] [get_bd_pins axi_periph/ACLK] [get_bd_pins axi_periph/S00_ACLK] [get_bd_pins axi_periph/M00_ACLK] [get_bd_pins axi_periph/M01_ACLK] [get_bd_pins led_gpio/s_axi_aclk] [get_bd_pins button_gpio/s_axi_aclk]
connect_bd_net [get_bd_ports s_axi_aresetn] [get_bd_pins axi_periph/ARESETN] [get_bd_pins axi_periph/S00_ARESETN] [get_bd_pins axi_periph/M00_ARESETN] [get_bd_pins axi_periph/M01_ARESETN] [get_bd_pins led_gpio/s_axi_aresetn] [get_bd_pins button_gpio/s_axi_aresetn]
connect_bd_net [get_bd_pins led_gpio/gpio_io_o] [get_bd_ports led_o]
connect_bd_net [get_bd_pins button_gpio/gpio_io_i] [get_bd_ports btn_i]
connect_bd_net [get_bd_pins button_gpio/ip2intc_irpt] [get_bd_ports irq]
assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces S_AXI] [get_bd_addr_segs led_gpio/S_AXI/Reg]
assign_bd_address -offset 0x00010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces S_AXI] [get_bd_addr_segs button_gpio/S_AXI/Reg]
validate_bd_design
save_bd_design
write_bd_tcl -force $build_dir/gpio_subsystem_recreate.tcl
set bd [get_files */gpio_subsystem.bd]
generate_target all $bd
make_wrapper -files $bd -top -force
set wrapper [file join [file dirname [lindex $bd 0]] hdl gpio_subsystem_wrapper.v]
add_files -norecurse $wrapper
set_property top gpio_subsystem_wrapper [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir $ip_dir -vendor f115112124.org -library user -taxonomy /UserIP -import_files
set core [ipx::current_core]
set_property name hw2_gpio_ip $core
set_property display_name {HW2 LED and Button GPIO} $core
set_property description {Reusable LED output and button interrupt GPIO subsystem for EGO-XZ7 HW2. ARM firmware retains counting and timing.} $core
set_property version 1.0 $core
set_property vendor_display_name {HW2 Student Project} $core
set_property company_url {https://github.com/f115112124/EGO-XZ7-HW2.1} $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
file copy [file join $build_dir gpio_subsystem_recreate.tcl] [file join $ip_dir gpio_subsystem_recreate.tcl]
puts "HW2_GPIO_PACKAGE_OK: $ip_dir/component.xml"
# Keep the source BD open when sourced from the GUI, for inspecting GPIO settings.
