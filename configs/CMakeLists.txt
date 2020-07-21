cmake_minimum_required(VERSION 3.12)

# Replace <the project name> with whatever you want to call the project
project(<the project name>)

# Replace <version> with a value in the format "X.Y.Z", replacing the
# letters with integers. In order, they correspond to major, minor and
# patch versions of your package

set(${PROJECT_NAME}_VERSION <version>)

# Gain access to the DAQ module functions
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../daq-buildtools/cmake ${CMAKE_MODULE_PATH})
include(DAQ)

daq_setup_environment()

# Assume we want to use the DAQModule class, provided by appfwk
find_package(appfwk)
# ...and optionally include other dependencies via find_package calls here

##############################################################################
point_build_to( src )

# Here we build a library named after the project; this may or may not
# be appropriate based on your needs

# Replace "<src1> ..." with actual source files
add_library(${PROJECT_NAME} <src1> ...)

# Replace "<lib1> ..." with any additional libraries you need besides
# the appfwk library. Keep in mind appfwk brings in other libraries
# (ers, Folly, etc.)

target_link_libraries(${PROJECT_NAME} PUBLIC appfwk::appfwk <lib1> ...)

target_include_directories(${PROJECT_NAME} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}> )

##############################################################################
point_build_to( apps )

# Add your project's executables (if any) here

##############################################################################
point_build_to( test )

# Add integration test applications here

##############################################################################
point_build_to( unittest )

# Add unit test applications here. Use the add_unit_test function from the DAQ module

##############################################################################

# Note it's assumed here in the installation call - but not necessarily
# the case in real life - that you've built a library with the same name
# as your project. Replace "<target1> ..." with any additional targets
# you've defined from the ./src or ./apps subdirectories. 

daq_install(VERSION ${${PROJECT_NAME}_VERSION} TARGETS ${PROJECT_NAME} <target1> ...)
