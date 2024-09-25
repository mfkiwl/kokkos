#These are tribits wrappers used by all projects in the Kokkos ecosystem

INCLUDE(CMakeParseArguments)
INCLUDE(CTest)

FUNCTION(ASSERT_DEFINED VARS)
  FOREACH(VAR ${VARS})
    IF(NOT DEFINED ${VAR})
      MESSAGE(SEND_ERROR "Error, the variable ${VAR} is not defined!")
    ENDIF()
  ENDFOREACH()
ENDFUNCTION()

MACRO(APPEND_GLOB VAR)
  FILE(GLOB LOCAL_TMP_VAR ${ARGN})
  LIST(APPEND ${VAR} ${LOCAL_TMP_VAR})
ENDMACRO()

MACRO(GLOBAL_SET VARNAME)
  SET(${VARNAME} ${ARGN} CACHE INTERNAL "" FORCE)
ENDMACRO()

MACRO(PREPEND_GLOBAL_SET VARNAME)
  ASSERT_DEFINED(${VARNAME})
  GLOBAL_SET(${VARNAME} ${ARGN} ${${VARNAME}})
ENDMACRO()

MACRO(ADD_INTERFACE_LIBRARY LIB_NAME)
  FILE(WRITE ${CMAKE_CURRENT_BINARY_DIR}/dummy.cpp "")
  ADD_LIBRARY(${LIB_NAME} STATIC ${CMAKE_CURRENT_BINARY_DIR}/dummy.cpp)
  SET_TARGET_PROPERTIES(${LIB_NAME} PROPERTIES INTERFACE TRUE)
ENDMACRO()

FUNCTION(KOKKOS_ADD_TEST)
  CMAKE_PARSE_ARGUMENTS(TEST
    "WILL_FAIL;SKIP_TRIBITS"
    "FAIL_REGULAR_EXPRESSION;PASS_REGULAR_EXPRESSION;EXE;NAME;TOOL"
    "CATEGORIES;ARGS"
    ${ARGN})
  # To match Tribits, we should always be receiving
  # the root names of exes/libs
  IF(TEST_EXE)
    SET(EXE_ROOT ${TEST_EXE})
  ELSE()
    SET(EXE_ROOT ${TEST_NAME})
  ENDIF()
  # Prepend package name to the test name
  # These should be the full target name
  SET(TEST_NAME ${PACKAGE_NAME}_${TEST_NAME})

  # For compatibility with Trilinos testing, we support:
  #  * `-D <fullTestName>_DISABLE=ON`
  #  * `-D <fullTestName>_EXTRA_ARGS="<arg0>;<arg1>;<arg2>;..."`
  #  * `-D <fullTestName>_SET_RUN_SERIAL=ON`
  IF(${TEST_NAME}_DISABLE)
    RETURN()
  ENDIF()

  SET(EXE ${PACKAGE_NAME}_${EXE_ROOT})
  IF(WIN32)
    ADD_TEST(NAME ${TEST_NAME} WORKING_DIRECTORY ${LIBRARY_OUTPUT_PATH}
      COMMAND ${EXE}${CMAKE_EXECUTABLE_SUFFIX} ${TEST_ARGS} ${${TEST_NAME}_EXTRA_ARGS})
  ELSE()
    ADD_TEST(NAME ${TEST_NAME} COMMAND ${EXE} ${TEST_ARGS} ${${TEST_NAME}_EXTRA_ARGS})
  ENDIF()
  # Trilinos testing benefits from labeling the tests as "Kokkos" tests
  SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES LABELS Kokkos)
  IF(${TEST_NAME}_SET_RUN_SERIAL)
    SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES RUN_SERIAL ON)
  ENDIF()
  # TriBITS doesn't actually currently support `-D <fullTestName>_ENVIRONMENT`
  # but we decided to add it anyway
  IF(${TEST_NAME}_ENVIRONMENT)
    SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES ENVIRONMENT "${${TEST_NAME}_ENVIRONMENT}")
  ENDIF()
  IF(TEST_WILL_FAIL)
    SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES WILL_FAIL ${TEST_WILL_FAIL})
  ENDIF()
  IF(TEST_FAIL_REGULAR_EXPRESSION)
    SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES FAIL_REGULAR_EXPRESSION ${TEST_FAIL_REGULAR_EXPRESSION})
  ENDIF()
  IF(TEST_PASS_REGULAR_EXPRESSION)
    SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES PASS_REGULAR_EXPRESSION ${TEST_PASS_REGULAR_EXPRESSION})
  ENDIF()
  IF(TEST_TOOL)
    ADD_DEPENDENCIES(${EXE} ${TEST_TOOL}) #make sure the exe has to build the tool
    SET_PROPERTY(TEST ${TEST_NAME} APPEND_STRING PROPERTY ENVIRONMENT "KOKKOS_PROFILE_LIBRARY=$<TARGET_FILE:${TEST_TOOL}>")
  ENDIF()
  VERIFY_EMPTY(KOKKOS_ADD_TEST ${TEST_UNPARSED_ARGUMENTS})
ENDFUNCTION()

MACRO(KOKKOS_CREATE_IMPORTED_TPL_LIBRARY TPL_NAME)
  ADD_INTERFACE_LIBRARY(TPL_LIB_${TPL_NAME})
  TARGET_LINK_LIBRARIES(TPL_LIB_${TPL_NAME} LINK_PUBLIC ${TPL_${TPL_NAME}_LIBRARIES})
  TARGET_INCLUDE_DIRECTORIES(TPL_LIB_${TPL_NAME} INTERFACE ${TPL_${TPL_NAME}_INCLUDE_DIRS})
ENDMACRO()

FUNCTION(KOKKOS_TPL_FIND_INCLUDE_DIRS_AND_LIBRARIES TPL_NAME)
  CMAKE_PARSE_ARGUMENTS(PARSE
    ""
    ""
    "REQUIRED_HEADERS;REQUIRED_LIBS_NAMES"
    ${ARGN})

  SET(_${TPL_NAME}_ENABLE_SUCCESS TRUE)
  IF (PARSE_REQUIRED_LIBS_NAMES)
    FIND_LIBRARY(TPL_${TPL_NAME}_LIBRARIES NAMES ${PARSE_REQUIRED_LIBS_NAMES})
    IF(NOT TPL_${TPL_NAME}_LIBRARIES)
      SET(_${TPL_NAME}_ENABLE_SUCCESS FALSE)
    ENDIF()
  ENDIF()
  IF (PARSE_REQUIRED_HEADERS)
    FIND_PATH(TPL_${TPL_NAME}_INCLUDE_DIRS NAMES ${PARSE_REQUIRED_HEADERS})
    IF(NOT TPL_${TPL_NAME}_INCLUDE_DIRS)
      SET(_${TPL_NAME}_ENABLE_SUCCESS FALSE)
    ENDIF()
  ENDIF()
  IF (_${TPL_NAME}_ENABLE_SUCCESS)
    KOKKOS_CREATE_IMPORTED_TPL_LIBRARY(${TPL_NAME})
  ENDIF()
  VERIFY_EMPTY(KOKKOS_CREATE_IMPORTED_TPL_LIBRARY ${PARSE_UNPARSED_ARGUMENTS})
ENDFUNCTION()

FUNCTION(KOKKOS_LIB_TYPE LIB RET)
GET_TARGET_PROPERTY(PROP ${LIB} TYPE)
IF (${PROP} STREQUAL "INTERFACE_LIBRARY")
  SET(${RET} "INTERFACE" PARENT_SCOPE)
ELSE()
  SET(${RET} "PUBLIC" PARENT_SCOPE)
ENDIF()
ENDFUNCTION()

FUNCTION(KOKKOS_TARGET_INCLUDE_DIRECTORIES TARGET)
  IF(TARGET ${TARGET})
    #the target actually exists - this means we are doing separate libs
    #or this a test library
    KOKKOS_LIB_TYPE(${TARGET} INCTYPE)
    TARGET_INCLUDE_DIRECTORIES(${TARGET} ${INCTYPE} ${ARGN})
  ELSE()
    GET_PROPERTY(LIBS GLOBAL PROPERTY KOKKOS_LIBRARIES_NAMES)
    IF (${TARGET} IN_LIST LIBS)
       SET_PROPERTY(GLOBAL APPEND PROPERTY KOKKOS_LIBRARY_INCLUDES ${ARGN})
    ELSE()
      MESSAGE(FATAL_ERROR "Trying to set include directories on unknown target ${TARGET}")
    ENDIF()
  ENDIF()
ENDFUNCTION()

FUNCTION(KOKKOS_LINK_INTERNAL_LIBRARY TARGET DEPLIB)
  SET(options INTERFACE)
  SET(oneValueArgs)
  SET(multiValueArgs)
  CMAKE_PARSE_ARGUMENTS(PARSE
    "INTERFACE"
    ""
    ""
    ${ARGN})
  SET(LINK_TYPE)
  IF(PARSE_INTERFACE)
    SET(LINK_TYPE INTERFACE)
  ELSE()
    SET(LINK_TYPE PUBLIC)
  ENDIF()
  TARGET_LINK_LIBRARIES(${TARGET} ${LINK_TYPE} ${DEPLIB})
  VERIFY_EMPTY(KOKKOS_LINK_INTERNAL_LIBRARY ${PARSE_UNPARSED_ARGUMENTS})
ENDFUNCTION()

FUNCTION(KOKKOS_ADD_TEST_LIBRARY NAME)
  SET(oneValueArgs)
  SET(multiValueArgs HEADERS SOURCES)

  CMAKE_PARSE_ARGUMENTS(PARSE
    "STATIC;SHARED"
    ""
    "HEADERS;SOURCES;DEPLIBS"
    ${ARGN})

  SET(LIB_TYPE)
  IF (PARSE_STATIC)
    SET(LIB_TYPE STATIC)
  ELSEIF (PARSE_SHARED)
    SET(LIB_TYPE SHARED)
  ENDIF()

  IF(PARSE_HEADERS)
    LIST(REMOVE_DUPLICATES PARSE_HEADERS)
  ENDIF()
  IF(PARSE_SOURCES)
    LIST(REMOVE_DUPLICATES PARSE_SOURCES)
  ENDIF()
  ADD_LIBRARY(${NAME} ${LIB_TYPE} ${PARSE_SOURCES})
  IF (PARSE_DEPLIBS)
    TARGET_LINK_LIBRARIES(${NAME} PRIVATE ${PARSE_DEPLIBS})
  ENDIF()
ENDFUNCTION()


FUNCTION(KOKKOS_INCLUDE_DIRECTORIES)
  CMAKE_PARSE_ARGUMENTS(
    INC
    "REQUIRED_DURING_INSTALLATION_TESTING"
    ""
    ""
    ${ARGN}
  )
  INCLUDE_DIRECTORIES(${INC_UNPARSED_ARGUMENTS})
ENDFUNCTION()


MACRO(PRINTALL match)
get_cmake_property(_variableNames VARIABLES)
list (SORT _variableNames)
foreach (_variableName ${_variableNames})
  if("${_variableName}" MATCHES "${match}")
    message(STATUS "${_variableName}=${${_variableName}}")
  endif()
endforeach()
ENDMACRO()

MACRO(SET_GLOBAL_REPLACE SUBSTR VARNAME)
  STRING(REPLACE ${SUBSTR} ${${VARNAME}} TEMP)
  GLOBAL_SET(${VARNAME} ${TEMP})
ENDMACRO()

FUNCTION(GLOBAL_APPEND VARNAME)
  #We make this a function since we are setting variables
  #and want to use scope to avoid overwriting local variables
  SET(TEMP ${${VARNAME}})
  LIST(APPEND TEMP ${ARGN})
  GLOBAL_SET(${VARNAME} ${TEMP})
ENDFUNCTION()
