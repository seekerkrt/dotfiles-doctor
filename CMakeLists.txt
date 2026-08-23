cmake_minimum_required(VERSION 3.20)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" DOTDOC_PROJECT_VERSION)
string(STRIP "${DOTDOC_PROJECT_VERSION}" DOTDOC_PROJECT_VERSION)

project(dotfiles-doctor VERSION "${DOTDOC_PROJECT_VERSION}" LANGUAGES CXX)

set(DOTDOC_COMPILE_COMMANDS_LINK
    "${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json"
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    file(RELATIVE_PATH DOTDOC_COMPILE_COMMANDS_TARGET
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json"
    )

    file(CREATE_LINK
        "${DOTDOC_COMPILE_COMMANDS_TARGET}"
        "${DOTDOC_COMPILE_COMMANDS_LINK}"
        SYMBOLIC
    )
elseif(IS_SYMLINK "${DOTDOC_COMPILE_COMMANDS_LINK}")
    file(REMOVE "${DOTDOC_COMPILE_COMMANDS_LINK}")
endif()

include(GNUInstallDirs)

add_executable(dotdoc
    source/dotdoctor.cpp
)

target_compile_definitions(dotdoc PRIVATE
    DOTDOC_VERSION="${PROJECT_VERSION}"
)

target_compile_features(dotdoc PRIVATE cxx_std_20)

set_target_properties(dotdoc PROPERTIES
    CXX_EXTENSIONS OFF
)

target_compile_options(dotdoc PRIVATE
    -Wall
    -Wextra
    -Wpedantic
)

include(CTest)

if(BUILD_TESTING)
    add_test(
        NAME dotdoc_integration
        COMMAND sh
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_dotdoc.sh
            $<TARGET_FILE:dotdoc>
            ${PROJECT_VERSION}
    )
endif()

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/man/dotdoc.1.in
    ${CMAKE_CURRENT_BINARY_DIR}/dotdoc.1
    @ONLY
)

install(
    TARGETS dotdoc
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(
    FILES ${CMAKE_CURRENT_BINARY_DIR}/dotdoc.1
    DESTINATION ${CMAKE_INSTALL_MANDIR}/man1
)
