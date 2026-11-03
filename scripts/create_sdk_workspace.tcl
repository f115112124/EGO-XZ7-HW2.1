# Run in SDK 2018.3 XSCT Console, or with the installed SDK 2018.3 xsct.bat.
# This builds software only; it does not connect to or program hardware.

set project_root [file normalize [file join [file dirname [info script]] ..]]
set hardware_file [file join $project_root export design_1_wrapper.hdf]
set sdk_workspace [file join $project_root sdk]
set source_directory [file join $project_root firmware hw2_demo]

if {[catch {
    if {![file isfile $hardware_file]} {
        error "Exported hardware does not exist: $hardware_file"
    }
    if {![file isfile [file join $source_directory main.c]]} {
        error "Application source does not exist: $source_directory/main.c"
    }

    setws $sdk_workspace
    if {![file isfile [file join $sdk_workspace hw_platform .project]]} {
        createhw -name hw_platform -hwspec $hardware_file
    } else {
        updatehw -hw hw_platform -newhwspec $hardware_file
    }

    if {![file isfile [file join $sdk_workspace standalone_bsp .project]]} {
        createbsp -name standalone_bsp -hwproject hw_platform \
            -proc ps7_cortexa9_0 -os standalone
    }
    if {![file isfile [file join $sdk_workspace hw2_demo .project]]} {
        createapp -name hw2_demo -hwproject hw_platform \
            -proc ps7_cortexa9_0 -bsp standalone_bsp \
            -app {Empty Application} -lang c
    }

    importsources -name hw2_demo -path $source_directory
    projects -build -type bsp -name standalone_bsp
    projects -build -type app -name hw2_demo

    set elf_file [file join $sdk_workspace hw2_demo Debug hw2_demo.elf]
    if {![file isfile $elf_file]} {
        error "Build did not produce the expected ELF: $elf_file"
    }
    puts "SDK_BUILD_OK: $elf_file ([file size $elf_file] bytes)"
    # Keep a matching, relocatable prebuilt set without copying the SDK workspace.
    set demo_directory [file join $project_root demo_ip]
    file mkdir $demo_directory
    file copy -force [file join $project_root export design_1_wrapper.bit] [file join $demo_directory design_1_wrapper.bit]
    file copy -force $elf_file [file join $demo_directory hw2_demo.elf]
    file copy -force [file join $sdk_workspace hw_platform ps7_init.tcl] [file join $demo_directory ps7_init.tcl]
    puts "SDK_PAIRED_DEMO_READY: $demo_directory"
} build_error build_options]} {
    puts stderr "SDK_BUILD_FAILED: $build_error"
    if {[dict exists $build_options -errorinfo]} {
        puts stderr [dict get $build_options -errorinfo]
    }
    error $build_error
}
