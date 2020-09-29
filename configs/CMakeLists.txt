
cmake_minimum_required(VERSION 3.12)

project(dunedaq)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../daq-buildtools/cmake ${CMAKE_MODULE_PATH})

macro(subdirlist result curdir)
  file(GLOB children RELATIVE ${curdir} CONFIGURE_DEPENDS ${curdir}/*)
  set(dirlist "")
  foreach (child ${children})
    if (IS_DIRECTORY ${curdir}/${child})
      list(APPEND dirlist ${child})
    endif()
  endforeach()
  set(${result} ${dirlist})
endmacro()

subdirlist(subdirs ${CMAKE_CURRENT_LIST_DIR})

foreach (subdir ${subdirs})
  add_subdirectory(${subdir})
endforeach()
