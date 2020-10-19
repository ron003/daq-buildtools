
cmake_minimum_required(VERSION 3.12)

project(dunedaq)

include(GNUInstallDirs)

if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/daq-buildtools/cmake)
  set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/daq-buildtools/cmake ${CMAKE_MODULE_PATH})
else()
  find_package(daq-buildtools REQUIRED)  
endif()

include(DAQTopprojHelpers)

# "build_order" lists packages built via CMake currently
# found in https://github.com/DUNE-DAQ in the opposite order you'd
# want CMake to see them (via "add_subdirectory") during a
# simultaneous build. This is due to their dependencies: e.g., you'd
# want CMake to see daq-buildtools first in order to create
# daq-buildtoolsConfig.cmake so "find_package(daq-builtools)" will
# work for all the other packages, and so on. If a new package is
# introduced, however, it will be up to the developer to *first*
# build its dependencies before trying to build it.
set(build_order "daq-buildtools" "cmdlib" "restcmd" "appfwk" "ipm" "driver" "udaq-readout" "ddpdemo" "listrev")

daq_add_subpackages(${build_order}) 

