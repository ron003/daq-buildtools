
cmake_minimum_required(VERSION 3.12)

project(dunedaq)

include(GNUInstallDirs)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/daq-buildtools/cmake ${CMAKE_MODULE_PATH})

include(DAQTopprojHelpers)

daq_add_subpackages() 
