# create ooc synthesis project
create_project riscy ./vivado/riscy -part xc7z020clg400-1 -force

# Optionally, add directories
add_files -norecurse ./src/design/riscy/
add_files -norecurse ./src/design/riscy/include/
add_files -norecurse ./src/design/zynq_system/
add_files -norecurse ./src/simulation/

update_compile_order -fileset sources_1

# Generate fpga system bd:
source ./scripts/generate_fpga_bd.tcl

# Generate simulation bd:
# source ./scripts/generate_sim_bd.tcl

# Set the bd wrapper as top for synthesis/implementation
set_property top riscv_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Set the tb zynq_tb as top for simulation
set_property top zynq_tb [get_filesets sim_1]