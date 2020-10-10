
cmake_minimum_required(VERSION 3.12)

project(dunedaq)

include(GNUInstallDirs)

if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/daq-buildtools/cmake)
  set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/daq-buildtools/cmake ${CMAKE_MODULE_PATH})
else()
  find_package(daq-buildtools REQUIRED)  
endif()

include(DAQTopprojHelpers)

daq_add_subpackages() 

