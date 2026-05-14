# Copyright 2018 ETH Zurich and University of Bologna.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

set project ariane
set vivado_project $project
if {[info exists ::env(CVA6_VIVADO_PROJECT)] && $::env(CVA6_VIVADO_PROJECT) ne ""} {
    set vivado_project $::env(CVA6_VIVADO_PROJECT)
}

create_project $vivado_project . -force -part $::env(XILINX_PART)
if {[info exists ::env(XILINX_BOARD)] && $::env(XILINX_BOARD) ne "none"} {
    set_property board_part $::env(XILINX_BOARD) [current_project]
}

# set number of threads to 8 (maximum, unfortunately)
set_param general.maxThreads 8

set_msg_config -id {[Synth 8-5858]} -new_severity "info"

set_msg_config -id {[Synth 8-4480]} -limit 1000
