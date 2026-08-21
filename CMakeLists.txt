cmake_minimum_required(VERSION 3.20)

project(dotfiles-doctor LANGUAGES CXX)

add_executable(dotdoctor
    src/dotdoctor.cpp
)

target_compile_features(dotdoctor PRIVATE cxx_std_20)

set_target_properties(dotdoctor PROPERTIES
    CXX_EXTENSIONS OFF
)

target_compile_options(dotdoctor PRIVATE
    -Wall
    -Wextra
    -Wpedantic
)

include(CTest)

if(BUILD_TESTING)
    add_test(
        NAME dotdoctor_smoke
        COMMAND dotdoctor
    )
endif()
