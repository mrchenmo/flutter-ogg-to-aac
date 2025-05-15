cmake_minimum_required(VERSION 3.10.2)

project("native_audio_converter")

# Path to libogg and libvorbis source code
# Using downloaded source code

# --- LIBOGG ---
set(LIBOGG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libs/libogg/libogg-1.3.5)
file(GLOB LIBOGG_SOURCES
    "${LIBOGG_DIR}/src/bitwise.c"
    "${LIBOGG_DIR}/src/framing.c")
add_library(ogg STATIC ${LIBOGG_SOURCES})
target_include_directories(ogg PUBLIC ${LIBOGG_DIR}/include)

# --- LIBVORBIS ---
set(LIBVORBIS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libs/libvorbis/libvorbis-1.3.7)
file(GLOB LIBVORBIS_SOURCES
    "${LIBVORBIS_DIR}/lib/analysis.c"
    "${LIBVORBIS_DIR}/lib/bitrate.c"
    "${LIBVORBIS_DIR}/lib/block.c"
    "${LIBVORBIS_DIR}/lib/codebook.c"
    "${LIBVORBIS_DIR}/lib/envelope.c"
    "${LIBVORBIS_DIR}/lib/floor0.c"
    "${LIBVORBIS_DIR}/lib/floor1.c"
    "${LIBVORBIS_DIR}/lib/info.c"
    "${LIBVORBIS_DIR}/lib/lookup.c"
    "${LIBVORBIS_DIR}/lib/lpc.c"
    "${LIBVORBIS_DIR}/lib/lsp.c"
    "${LIBVORBIS_DIR}/lib/mapping0.c"
    "${LIBVORBIS_DIR}/lib/mdct.c"
    "${LIBVORBIS_DIR}/lib/psy.c"
    "${LIBVORBIS_DIR}/lib/registry.c"
    "${LIBVORBIS_DIR}/lib/res0.c"
    "${LIBVORBIS_DIR}/lib/sharedbook.c"
    "${LIBVORBIS_DIR}/lib/smallft.c"
    "${LIBVORBIS_DIR}/lib/synthesis.c"
    "${LIBVORBIS_DIR}/lib/vorbisenc.c"
    "${LIBVORBIS_DIR}/lib/window.c")
add_library(vorbis STATIC ${LIBVORBIS_SOURCES})
target_include_directories(vorbis PUBLIC ${LIBVORBIS_DIR}/include)
target_link_libraries(vorbis ogg)

# --- LIBVORBISFILE ---
file(GLOB LIBVORBISFILE_SOURCES
    "${LIBVORBIS_DIR}/lib/vorbisfile.c")
add_library(vorbisfile STATIC ${LIBVORBISFILE_SOURCES})
target_include_directories(vorbisfile PUBLIC ${LIBVORBIS_DIR}/include)
target_link_libraries(vorbisfile vorbis)

# Add includes directory for header files
include_directories(includes)
include_directories(${LIBOGG_DIR}/include)
include_directories(${LIBVORBIS_DIR}/include)

# Add native_audio_converter library
add_library(native_audio_converter SHARED native-audio-converter.cpp)

# Link with necessary libraries
target_link_libraries(native_audio_converter
    android
    log
    ogg
    vorbis
    vorbisfile
)
