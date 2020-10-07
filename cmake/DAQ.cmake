
include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

####################################################################################################
# Experimental Color Support
if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(ColourBold  "${Esc}[1m")
  set(Red         "${Esc}[31m")
  set(Green       "${Esc}[32m")
  set(Yellow      "${Esc}[33m")
  set(Blue        "${Esc}[34m")
  set(Magenta     "${Esc}[35m")
  set(Cyan        "${Esc}[36m")
  set(White       "${Esc}[37m")
  set(BoldRed     "${Esc}[1;31m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
  set(BoldMagenta "${Esc}[1;35m")
  set(BoldCyan    "${Esc}[1;36m")
  set(BoldWhite   "${Esc}[1;37m")
endif()

####################################################################################################

# daq_setup_environment:
# This macro should be called immediately after the DAQ module is
# included in your DUNE DAQ project's CMakeLists.txt file; it ensures
# that DUNE DAQ projects all have a common build environment.

macro(daq_setup_environment)

  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_EXTENSIONS OFF)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)

  set(BUILD_SHARED_LIBS ON)

  # Include directories within CMAKE_SOURCE_DIR and CMAKE_BINARY_DIR should take precedence over everything else
  set(CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE ON)

  # All code for the project should be able to see the project's public include directory
  include_directories( ${CMAKE_SOURCE_DIR}/${PROJECT_NAME}/include )

  # Needed for clang-tidy (called by our linters) to work
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

  # Want find_package() to be able to locate packages we've installed in the 
  # local development area via daq_install(), defined later in this file
 
  set(CMAKE_PREFIX_PATH ${CMAKE_SOURCE_DIR}/../build ${CMAKE_SOURCE_DIR}/../install )

  set(CMAKE_INSTALL_LIBDIR ${PROJECT_NAME}/${CMAKE_INSTALL_LIBDIR})
  set(CMAKE_INSTALL_BINDIR ${PROJECT_NAME}/${CMAKE_INSTALL_BINDIR})
  set(CMAKE_INSTALL_INCLUDEDIR ${PROJECT_NAME}/${CMAKE_INSTALL_INCLUDEDIR})

  add_compile_options( -g -pedantic -Wall -Wextra -fdiagnostics-color=always )

  enable_testing()

endmacro()


####################################################################################################
# _daq_set_target_output_dirs
# This utility function updates the target output properites and points
# them to the chosen project subdirectory in the build ditrectory tree.
macro( _daq_set_target_output_dirs target output_dir )

  set_target_properties(${target}
    PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${output_dir}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${output_dir}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${output_dir}"
  )

endmacro()

####################################################################################################
macro( _daq_define_exportname )
  set( DAQ_PROJECT_EXPORTNAME ${PROJECT_NAME}Targets )
endmacro()


####################################################################################################
# daq_add_library:

function(daq_add_library)

  cmake_parse_arguments(LIBOPTS "" "" "LINK_LIBRARIES" ${ARGN})

  set(libname ${PROJECT_NAME})

  set(LIB_PATH "src")

  set(libsrcs)
  foreach(f ${LIBOPTS_UNPARSED_ARGUMENTS})

    if(${f} MATCHES ".*\\*.*")  # An argument with an "*" in it is treated as a glob

      set(fpaths)
      file(GLOB fpaths CONFIGURE_DEPENDS ${LIB_PATH}/${f})

      if (fpaths)
        set(libsrcs ${libsrcs} ${fpaths})
      else()
        message(WARNING "When defining list of files from which to build library \"${libname}\", no files in ${CMAKE_CURRENT_SOURCE_DIR}/${LIB_PATH} match the glob \"${f}\"")
      endif()
    else()
       # may be generated file, so just add
      set(libsrcs ${libsrcs} ${LIB_PATH}/${f})
    endif()
  endforeach()

  add_library(${libname} SHARED ${libsrcs})
  target_link_libraries(${libname} PUBLIC ${LIBOPTS_LINK_LIBRARIES}) 
  target_include_directories(${libname} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}> )

  _daq_set_target_output_dirs( ${libname} ${LIB_PATH} )

  _daq_define_exportname()
  install(TARGETS ${libname} EXPORT ${DAQ_PROJECT_EXPORTNAME} )

endfunction()

####################################################################################################
# daq_add_plugin:

function(daq_add_plugin pluginname plugintype)

  cmake_parse_arguments(PLUGOPTS "TEST" "" "LINK_LIBRARIES" ${ARGN})

  set(pluginlibname "${PROJECT_NAME}_${pluginname}_${plugintype}")

  set(PLUGIN_PATH "plugins")
  if(${PLUGOPTS_TEST})
    set(PLUGIN_PATH "test")
  endif()
  

  add_library( ${pluginlibname} MODULE ${PLUGIN_PATH}/${pluginname}.cpp )
  target_link_libraries(${pluginlibname} ${PLUGOPTS_LINK_LIBRARIES}) 

  _daq_set_target_output_dirs( ${pluginlibname} ${PLUGIN_PATH} )


  if ( NOT ${PLUGOPTS_TEST} )
    _daq_define_exportname()
    install(TARGETS ${pluginlibname} EXPORT ${DAQ_PROJECT_EXPORTNAME} DESTINATION ${CMAKE_INSTALL_LIBDIR})
  endif()

  endfunction()

####################################################################################################
# daq_add_app:
function(daq_add_application appname)
  
  cmake_parse_arguments(APPOPTS "TEST" "" "LINK_LIBRARIES" ${ARGN})

  set(APP_PATH "apps")
  if(${APPOPTS_TEST})
    set(APP_PATH "test")
  endif()

  set(appsrcs)
  foreach(f ${APPOPTS_UNPARSED_ARGUMENTS})

    if(${f} MATCHES ".*\\*.*")   # An argument with an "*" in it is treated as a glob

      set(fpaths)
      file(GLOB fpaths CONFIGURE_DEPENDS ${APP_PATH}/${f})

      if (fpaths)
        set(appsrcs ${appsrcs} ${fpaths})
      else()
        message(WARNING "When defining list of files from which to build application \"${appname}\", no files in ${CMAKE_CURRENT_SOURCE_DIR}/${APP_PATH} match the glob \"${f}\"")
      endif()
    else()
       # may be generated file, so just add
      set(appsrcs ${appsrcs} ${APP_PATH}/${f})
    endif()
  endforeach()

  
  add_executable(${appname} ${appsrcs})
  target_link_libraries(${appname} PUBLIC ${APPOPTS_LINK_LIBRARIES}) 

  _daq_set_target_output_dirs( ${appname} ${APP_PATH} )

  if( NOT ${APPOPTS_TEST} )
    _daq_define_exportname()
    install(TARGETS ${appname} EXPORT ${DAQ_PROJECT_EXPORTNAME} )
  endif()

endfunction()


####################################################################################################
# daq_add_unit_test:
# This function, when given the extension-free name of a unit test
# sourcefile in unittest/, will handle the needed boost functionality
# to build the unit test, as well as provide other support (CTest,
# etc.). Optional additional arguments can be libraries you need to
# link, e.g.
#
# daq_add_unit_test(FooLibrary_test Foo)

function(daq_add_unit_test testname)

  cmake_parse_arguments(UTEST "" "" "LINK_LIBRARIES" ${ARGN})

  set(UTEST_PATH "unittest")

  add_executable( ${testname} ${UTEST_PATH}/${testname}.cxx )
  target_link_libraries( ${testname} ${UTEST_LINK_LIBRARIES} ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})
  target_compile_definitions(${testname} PRIVATE "BOOST_TEST_DYN_LINK=1")
  add_test(NAME ${testname} COMMAND ${testname})

  _daq_set_target_output_dirs( ${testname} ${UTEST_PATH} )

endfunction()

####################################################################################################

# daq_install:
# This function should be called with a signature like the following:
#
# daq_install(TARGETS <target1> <target2> ...)
#

# ...where <target1> <target2> ... is the list of targets in your
#  project which you want installed. Conventionally this should be
#  targets from your src/ and apps/ subdirectories, and not include
#  your test apps.

function(daq_install) 

  set(cmakedestination ${CMAKE_INSTALL_LIBDIR}/${PROJECT_NAME}/cmake)

  _daq_define_exportname()
  install(EXPORT ${DAQ_PROJECT_EXPORTNAME} FILE ${DAQ_PROJECT_EXPORTNAME}.cmake NAMESPACE ${PROJECT_NAME}:: DESTINATION ${cmakedestination} )

  install(DIRECTORY include/${PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} FILES_MATCHING PATTERN "*.h??")

  set(versionfile        ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake)
  set(configfiletemplate ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}Config.cmake.in)
  set(configfile         ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake)

  if (DEFINED PROJECT_VERSION)
    write_basic_package_version_file(${versionfile} COMPATIBILITY ExactVersion)
  else()
    message(FATAL_ERROR "Error: the PROJECT_VERSION CMake variable needs to be defined in order to install. The way to do this is by adding the version to the project() call at the top of your CMakeLists.txt file, e.g. \"project(${PROJECT_NAME} VERSION 1.0.0)\"")
  endif()

  if (EXISTS ${configfiletemplate})
    configure_package_config_file(${configfiletemplate} ${configfile} INSTALL_DESTINATION ${cmakedestination})
  else()
     message(FATAL_ERROR "Error: unable to find needed file ${configfiletemplate} for ${PROJECT_NAME} installation")
  endif()

  install(FILES ${versionfile} ${configfile} DESTINATION ${cmakedestination})

endfunction()

####################################################################################################
