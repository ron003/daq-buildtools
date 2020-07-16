
include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

macro(daq_setup_environment)

  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_EXTENSIONS OFF)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)

  set(BUILD_SHARED_LIBS ON)

  # Directories should always be added *before* the current path
  set(CMAKE_INCLUDE_DIRECTORIES_PROJECT_BEFORE ON)
  include_directories( ${CMAKE_SOURCE_DIR}/include )

  # Needed for clang-tidy (called by our linters) to work
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

  # Want find_package() to be able to locate packages we've installed in the 
  # local development area via daq_install(), defined later in this file

  set(CMAKE_PREFIX_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../install )

  add_compile_options( -g -pedantic -Wall -Wextra )

  enable_testing()

endmacro()


function( point_build_to output_dir )

  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${output_dir} PARENT_SCOPE)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${output_dir} PARENT_SCOPE)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${output_dir} PARENT_SCOPE)

endfunction()

function(add_unit_test testname)

  add_executable( ${testname} unittest/${testname}.cxx )
  target_link_libraries( ${testname} ${ARGN} ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})
  target_compile_definitions(${testname} PRIVATE "BOOST_TEST_DYN_LINK=1")
  add_test(NAME ${testname} COMMAND ${testname})

endfunction()


function(daq_install) 

  cmake_parse_arguments(DAQ_INSTALL "" VERSION TARGETS ${ARGN} )

  set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_SOURCE_DIR}/../install/${PROJECT_NAME} CACHE PATH "No comment" FORCE)

  set(exportset ${PROJECT_NAME}Targets)
  set(cmakedestination ${CMAKE_INSTALL_LIBDIR}/${PROJECT_NAME}/cmake)

  install(TARGETS ${DAQ_INSTALL_TARGETS} EXPORT ${exportset} )
  install(EXPORT ${exportset} FILE ${exportset}.cmake NAMESPACE ${PROJECT_NAME}:: DESTINATION ${cmakedestination} )

  install(DIRECTORY include/${PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} FILES_MATCHING PATTERN "*.h??")

  set(versionfile        ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake)
  set(configfiletemplate ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}Config.cmake.in)
  set(configfile         ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake)

  write_basic_package_version_file(${versionfile} VERSION $DAQ_INSTALL_VERSION COMPATIBILITY ExactVersion)

  if (EXISTS ${configfiletemplate})
    configure_package_config_file(${configfiletemplate} ${configfile} INSTALL_DESTINATION ${cmakedestination})
  else()
     message(FATAL_ERROR "Error: unable to find needed file ${configfiletemplate} for ${PROJECT_NAME} installation")
  endif()

  install(FILES ${versionfile} ${configfile} DESTINATION ${cmakedestination})

endfunction()
