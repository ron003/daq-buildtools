cmake_minimum_required(VERSION 3.12)
project(YourPackageName VERSION 1.0.0)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../daq-buildtools/cmake ${CMAKE_MODULE_PATH})
include(DAQ)

daq_setup_environment()

find_package(appfwk        REQUIRED)
find_package(SomeExternalPackage REQUIRED)

##############################################################################
daq_point_build_to( src )

add_library(           YourPackageName_AModuleName_duneDAQModule       src/AModuleName.cpp)
target_link_libraries( YourPackageName_AModuleName_duneDAQModule       appfwk::appfwk)

add_library(           YourPackageName_AnotherModuleName_duneDAQModule src/AnotherModuleName.cpp)
target_link_libraries( YourPackageName_AnotherModuleName_duneDAQModule appfwk::appfwk)

##############################################################################
daq_point_build_to( unittest )

daq_add_unit_test(AModuleName_test          YourPackageName_AModuleName_duneDAQModule)
daq_add_unit_test(AnotherModuleName_test    YourPackageName_AnotherModuleName_duneDAQModule) 

##############################################################################

daq_install(TARGETS YourPackageName_AModuleName_duneDAQModule YourPackageName_AnotherModuleName_duneDAQModule)



