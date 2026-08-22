cmake_minimum_required(VERSION 3.20)

project(dotfiles-doctor VERSION 0.1.0 LANGUAGES CXX)

add_executable(dotdoc
    src/dotdoctor.cpp
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
