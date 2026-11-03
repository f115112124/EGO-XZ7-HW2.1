# Source this file in Vivado 2018.3 Tcl Console.
# All paths are relative to this script, so the package can be relocated.
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]]} {
    error "Close the current project first (File > Close Project), then source this script again."
}
if {[file exists $root/hardware/soc_hw2_ip.xpr]} {
    error "Project already exists. Use File > Open Project: $root/hardware/soc_hw2_ip.xpr"
}
foreach folder {hardware export reports} {file mkdir $root/$folder}
set jobs 4
proc stage {message} {puts "HW2_STAGE: $message"}
stage "Creating EGO-XZ7 hardware (Vivado 2018.3, xc7z020clg484-1)"
create_project soc_hw2_ip $root/hardware -part xc7z020clg484-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property ip_repo_paths [file join $root ip_repo] [current_project]
update_ip_catalog
set custom_vlnv f115112124.org:user:hw2_gpio_ip:1.0
if {[llength [get_ipdefs -quiet $custom_vlnv]] != 1} {
    error "Packaged hw2_gpio_ip 1.0 was not found in $root/ip_repo"
}
create_bd_design design_1

source $root/reference/ego_ps7_reference.tcl
foreach {key value} {
    CONFIG.PCW_USE_M_AXI_GP0 1
    CONFIG.PCW_EN_CLK0_PORT 1
    CONFIG.PCW_EN_RST0_PORT 1
    CONFIG.PCW_USE_FABRIC_INTERRUPT 1
    CONFIG.PCW_IRQ_F2P_INTR 1
    CONFIG.PCW_EN_EMIO_WP_SDIO0 0
    CONFIG.PCW_SD0_GRP_WP_ENABLE 0
    CONFIG.PCW_EN_EMIO_WDT 0
    CONFIG.PCW_EN_WDT 0
    CONFIG.PCW_WDT_PERIPHERAL_ENABLE 0
} {dict set ego_ps7_reference $key $value}
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
set_property -dict $ego_ps7_reference [get_bd_cells processing_system7_0]

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR
create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/DDR] [get_bd_intf_ports DDR]
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/FIXED_IO] [get_bd_intf_ports FIXED_IO]

# One reusable packaged GPIO subsystem replaces the two separate top-level GPIOs.
create_bd_cell -type ip -vlnv $custom_vlnv hw2_gpio_ip_0
create_bd_port -dir O -from 7 -to 0 leds_8bits_tri_o
create_bd_port -dir I -from 4 -to 0 btns_5bits_tri_i
connect_bd_net [get_bd_pins hw2_gpio_ip_0/led_o] [get_bd_ports leds_8bits_tri_o]
connect_bd_net [get_bd_pins hw2_gpio_ip_0/btn_i] [get_bd_ports btns_5bits_tri_i]
connect_bd_net [get_bd_pins hw2_gpio_ip_0/irq] [get_bd_pins processing_system7_0/IRQ_F2P]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps7_0_axi_periph
set_property -dict [list CONFIG.NUM_SI 1 CONFIG.NUM_MI 1] [get_bd_cells ps7_0_axi_periph]
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins ps7_0_axi_periph/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M00_AXI] [get_bd_intf_pins hw2_gpio_ip_0/S_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50M
set_property CONFIG.C_AUX_RESET_HIGH 1 [get_bd_cells rst_ps7_0_50M]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 reset_zero
set_property CONFIG.CONST_VAL 0 [get_bd_cells reset_zero]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 reset_locked
set_property CONFIG.CONST_VAL 1 [get_bd_cells reset_locked]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] \
    [get_bd_pins ps7_0_axi_periph/ACLK] [get_bd_pins ps7_0_axi_periph/S00_ACLK] \
    [get_bd_pins ps7_0_axi_periph/M00_ACLK] \
    [get_bd_pins hw2_gpio_ip_0/s_axi_aclk] \
    [get_bd_pins rst_ps7_0_50M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_50M/ext_reset_in]
connect_bd_net [get_bd_pins reset_zero/dout] [get_bd_pins rst_ps7_0_50M/aux_reset_in] [get_bd_pins rst_ps7_0_50M/mb_debug_sys_rst]
connect_bd_net [get_bd_pins reset_locked/dout] [get_bd_pins rst_ps7_0_50M/dcm_locked]
connect_bd_net [get_bd_pins rst_ps7_0_50M/interconnect_aresetn] [get_bd_pins ps7_0_axi_periph/ARESETN] [get_bd_pins ps7_0_axi_periph/S00_ARESETN]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] \
    [get_bd_pins ps7_0_axi_periph/M00_ARESETN] \
    [get_bd_pins hw2_gpio_ip_0/s_axi_aresetn]
set custom_segments [get_bd_addr_segs -of_objects [get_bd_intf_pins hw2_gpio_ip_0/S_AXI]]
if {[llength $custom_segments] != 1} {error "Expected exactly one packaged-IP register window: $custom_segments"}
assign_bd_address -offset 0x41200000 -range 0x00020000 $custom_segments
validate_bd_design
if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells rst_ps7_0_50M]] != 1} {error "Auxiliary reset polarity must be ACTIVE_HIGH for the constant-zero input"}
save_bd_design
write_bd_tcl -force $root/export/design_1_recreate.tcl
stage "Generating IP outputs and HDL wrapper"
set bd [get_files */design_1.bd]
generate_target all $bd
make_wrapper -files $bd -top -force
set wrapper [file join [file dirname [lindex $bd 0]] hdl design_1_wrapper.v]
add_files -norecurse $wrapper
set_property top design_1_wrapper [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse $root/constraints/ego_xz7.xdc
update_compile_order -fileset sources_1


puts "HW2_PROJECT_READY: $root/hardware/soc_hw2_ip.xpr"
