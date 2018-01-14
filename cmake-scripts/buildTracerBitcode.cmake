function(build_tracer_bitcode TEST_NAME f_SRC WORKLOAD)
  set(TARGET_NAME "Tracer_${TEST_NAME}")
  set(OBJ_LLVM "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.${LLVM_EXT}")
  set(OPT_OBJ_LLVM "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}-opt.${LLVM_EXT}")
  set(FULL_OPT_LLVM "${CMAKE_CURRENT_BINARY_DIR}/full.${LLVM_EXT}")
  set(FULL_S "${CMAKE_CURRENT_BINARY_DIR}/full.s")
  set(RAW_EXE "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}")
  set(PROFILE_EXE "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}-instrumented")
  set(TRACE_LOGGER "${CMAKE_CURRENT_BINARY_DIR}/../../profile-func/trace_logger.${LLVM_EXT}")

  set(FULLTRACE_SO "$<TARGET_FILE:full_trace>")

  set(CFLAGS "-g" "-O1" "-fno-slp-vectorize" "-fno-vectorize"
		"-fno-unroll-loops" "-fno-inline" "-fno-builtin"
                "-I${ZLIB_INCLUDE_DIRS}")

  set(OPT_FLAGS "-disable-inlining" "-S" "-load=${FULLTRACE_SO}" "-fulltrace")
  set(LLC_FLAGS "-O0" "-disable-fp-elim" "-filetype=asm")
  set(FINAL_CXX_FLAGS "-O0" "-fno-inline")

  # I can not link library like "-l/foo/bar/libz.so"
  # so rearrange it as "-L/foo/bar/ -lz"
  # The rpath may not be necessary. Rpath forces program loader to search
  # dynamic libraries form it, rather than system library path.
  # Therefore I can check the linking through "ldd" command
  get_filename_component(ZLIB_LIB_DIR ${ZLIB_LIBRARIES} DIRECTORY)
  set(FINAL_CXX_LDFLAGS "-lm" "-L${ZLIB_LIB_DIR}" "-lz" "-Wl,-rpath=${ZLIB_LIB_DIR}")

  
  set(LLVMC_FLAGS ${LLVMC_FLAGS} ${CFLAGS})
  build_llvm_bitcode(${TEST_NAME} ${f_SRC})

  add_custom_command(OUTPUT ${OPT_OBJ_LLVM} DEPENDS ${OBJ_LLVM}
    COMMAND WORKLOAD=${WORKLOAD} ${LLVM_OPT} ${OPT_FLAGS} ${OBJ_LLVM} -o ${OPT_OBJ_LLVM}
    VERBATIM)

  add_custom_command(OUTPUT ${FULL_OPT_LLVM} DEPENDS ${OPT_OBJ_LLVM} 
    COMMAND ${LLVM_LINK} -o ${FULL_OPT_LLVM} ${OPT_OBJ_LLVM} ${TRACE_LOGGER}
    VERBATIM)

  add_custom_command(OUTPUT ${FULL_S} DEPENDS ${FULL_OPT_LLVM}
    COMMAND ${LLVM_LLC} ${LLC_FLAGS} -o ${FULL_S}  ${FULL_OPT_LLVM}
    VERBATIM)

  add_custom_command(OUTPUT ${PROFILE_EXE} DEPENDS ${FULL_S}
    COMMAND g++ ${FINAL_CXX_FLAGS} -o ${PROFILE_EXE} ${FULL_S} ${FINAL_CXX_LDFLAGS}
    VERBATIM)


  add_custom_target(${TARGET_NAME} ALL DEPENDS ${PROFILE_EXE})
  add_dependencies(${TARGET_NAME} PROFILE_FUNC full_trace)

  add_test(NAME ${TEST_NAME} COMMAND ${PROFILE_EXE})
endfunction(build_tracer_bitcode)
