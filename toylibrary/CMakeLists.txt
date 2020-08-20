cmake_minimum_required(VERSION 3.12)
project(toylibrary VERSION 1.1.0)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../daq-buildtools/cmake ${CMAKE_MODULE_PATH})
include(DAQ)

daq_setup_environment()

# ers: for exceptions and normal output
# TRACE: for low-level debugging statements
# Boost unit_test_framework: for the unit tests
# Boost program_options: to allow command line options with descriptions/default values

find_package(ers REQUIRED)     
find_package(TRACE REQUIRED)
find_package(Boost COMPONENTS unit_test_framework program_options REQUIRED)

##############################################################################

# Note that when the ers library is linked in, it uses a "::" because
# it's in an external package, not a local CMake target. The semantics
# are <namespace>::<shared library / executable>

daq_point_build_to( src )

add_library(               toylibrary       src/IntPrinter.cpp )
target_link_libraries(     toylibrary       ers::ers)
target_include_directories(toylibrary 
		           PUBLIC 
                           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
			   $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}> 
			   )

##############################################################################
daq_point_build_to( test )

add_executable(        toylibrary_test_program test/toylibrary_test_program.cxx)
target_link_libraries( toylibrary_test_program ${Boost_PROGRAM_OPTIONS_LIBRARY} toylibrary)

##############################################################################
daq_point_build_to( unittest )

daq_add_unit_test(ValueWrapper_test)

##############################################################################

# Could add "toylibrary_test_program" to the argument list here, but
# presumably end users wouldn't care about an integration test program
# and just want the shared object library installed

daq_install(TARGETS toylibrary)



