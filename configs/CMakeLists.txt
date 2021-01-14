
cmake_minimum_required(VERSION 3.12)

project(dunedaq)

include(GNUInstallDirs)

set(CMAKE_MODULE_PATH ${DBT_ROOT}/cmake ${CMAKE_MODULE_PATH})
set(CMAKE_PREFIX_PATH ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_PREFIX_PATH})

message(STATUS "CMAKE_MODULE_PATH=${CMAKE_MODULE_PATH}")

include(DAQTopprojHelpers)

# Load build_order variable from file
include(./dbt-build-order.cmake)

daq_add_subpackages("${build_order}") 

