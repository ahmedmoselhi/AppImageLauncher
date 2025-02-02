# define private libraries install destination
include(GNUInstallDirs)

# debugging: libdir should be lib/<triplet>
message(STATUS "CMAKE_INSTALL_LIBDIR: ${CMAKE_INSTALL_LIBDIR}")

if(NOT IS_ABSOLUTE ${CMAKE_INSTALL_LIBDIR})
    set(_libdir ${CMAKE_INSTALL_LIBDIR})
else()
    file(RELATIVE_PATH _libdir ${CMAKE_INSTALL_LIBDIR} ${CMAKE_INSTALL_PREFIX})
endif()

set(_private_libdir ${_libdir}/appimagelauncher)

# calculate relative path from binary install destination to private library install dir
if(NOT IS_ABSOLUTE ${CMAKE_INSTALL_BINDIR})
    set(_bindir ${CMAKE_INSTALL_BINDIR})
else()
    file(RELATIVE_PATH _bindir ${CMAKE_INSTALL_BINDIR} ${CMAKE_INSTALL_PREFIX})
    #set(_bindir ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR})
endif()

set(_abs_bindir ${CMAKE_INSTALL_PREFIX}/${_bindir})
set(_abs_private_libdir ${CMAKE_INSTALL_PREFIX}/${_private_libdir})

file(RELATIVE_PATH _rpath ${_abs_bindir} ${_abs_private_libdir})
set(_rpath "\$ORIGIN/${_rpath}")


# install libappimage.so into lib/appimagekit to avoid overwriting a libappimage potentially installed into /usr/lib
# or /usr/lib/x86_64-... or wherever the OS puts its libraries
# for some reason, using TARGETS ... doesn't work here, therefore using the absolute file path
file(GLOB libappimage_files ${PROJECT_BINARY_DIR}/lib/AppImageUpdate/lib/libappimage/src/libappimage/libappimage.so*)
file(GLOB libappimageupdate_files ${PROJECT_BINARY_DIR}/lib/AppImageUpdate/src/updater/libappimageupdate.so*)
file(GLOB libappimageupdate-qt_files ${PROJECT_BINARY_DIR}/lib/AppImageUpdate/src/qt-ui/libappimageupdate-qt.so*)

foreach(i libappimage libappimageupdate libappimageupdate-qt)
    # prevent unnecessary messages
    if(NOT i STREQUAL libappimage OR NOT USE_SYSTEM_LIBAPPIMAGE)
        if(NOT ${i}_files)
            message(WARNING "Could not find ${i} library files, cannot bundle; if you want to bundle the files, please re-run cmake before calling make install")
        else()
            install(
                FILES
                ${${i}_files}
                DESTINATION ${_private_libdir} COMPONENT APPIMAGELAUNCHER
            )
        endif()
    endif()
endforeach()

if(NOT BUILD_LITE)
    # unfortunately, due to a cyclic dependency, we need to hardcode parts of this variable, which is included in the
    # install scripts and the binfmt.d config
    set(BINFMT_INTERPRETER_PATH ${CMAKE_INSTALL_PREFIX}/${_private_libdir}/binfmt-interpreter)

    # according to https://www.kernel.org/doc/html/latest/admin-guide/binfmt-misc.html, we must make sure the
    # interpreter string does not exceed 127 characters
    set(BINFMT_INTERPRETER_PATH_LENGTH_MAX 127)
    string(LENGTH BINFMT_INTERPRETER_PATH BINFMT_INTERPRETER_PATH_LENGTH)

    if(BINFMT_INTERPRETER_PATH_LENGTH GREATER BINFMT_INTERPRETER_PATH_LENGTH_MAX)
        message(FATAL_ERROR "interpreter path exceeds maximum length of ${BINFMT_INTERPRETER_PATH_LENGTH_MAX}")
    endif()

    # binfmt.d config file -- used as a fallback, if update-binfmts is not available
    configure_file(
        ${PROJECT_SOURCE_DIR}/resources/binfmt.d/appimagelauncher.conf.in
        ${PROJECT_BINARY_DIR}/resources/binfmt.d/appimagelauncher.conf
        @ONLY
    )
    # caution: don't use ${CMAKE_INSTALL_LIBDIR} here, it's really just lib/binfmt.d
    install(
        FILES ${PROJECT_BINARY_DIR}/resources/binfmt.d/appimagelauncher.conf
        DESTINATION lib/binfmt.d COMPONENT APPIMAGELAUNCHER
    )
endif()

# install systemd service configuration for appimagelauncherd
configure_file(
    ${PROJECT_SOURCE_DIR}/resources/appimagelauncherd.service.in
    ${PROJECT_BINARY_DIR}/resources/appimagelauncherd.service
    @ONLY
)
# caution: don't use ${CMAKE_INSTALL_LIBDIR} here, it's really just lib/systemd/user
install(
    FILES ${PROJECT_BINARY_DIR}/resources/appimagelauncherd.service
    DESTINATION lib/systemd/user/ COMPONENT APPIMAGELAUNCHER
)
