// SPDX-FileCopyrightText: © 2025 Tenstorrent USA, Inc.
//
// SPDX-License-Identifier: Apache-2.0
//
// Device-free equivalent of Metalium's generated chlkc_descriptors.h for a
// ttWKV7 BFloat16 math kernel. Values mirror the retained Metalium JIT output.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

#include "llk_defs.h"

namespace ttwkv7_architecture_check {

constexpr std::size_t kCircularBufferCount = 64;
constexpr std::size_t kConfiguredCircularBufferCount = 32;
constexpr std::uint8_t kBfloat16DataFormat = 5;
constexpr std::uint8_t kInvalidDataFormat = 255;
constexpr std::uint8_t kTileFaceCount = 4;
constexpr std::uint8_t kTileFaceDimension = 16;
constexpr std::uint8_t kTileDimension = 32;
constexpr std::uint16_t kBfloat16TileSizeBytes = 2048;
constexpr std::uint16_t kInvalidTileSizeBytes = 1088;
constexpr std::uint8_t kTileFacesPerDimension = 2;

template <typename Value, std::size_t Count>
constexpr std::array<Value, Count> repeat_value(Value value) {
  std::array<Value, Count> result{};
  for (Value &item : result) {
    item = value;
  }
  return result;
}

template <typename Value, std::size_t Count, typename Generator>
constexpr std::array<Value, Count> generate_values(Generator generator) {
  std::array<Value, Count> result{};
  for (std::size_t index = 0; index < Count; ++index) {
    result[index] = generator(index);
  }
  return result;
}

constexpr std::uint8_t data_format_for_index(std::size_t index) {
  return index < kConfiguredCircularBufferCount ? kBfloat16DataFormat
                                                : kInvalidDataFormat;
}

constexpr std::uint16_t tile_size_for_index(std::size_t index) {
  return index < kConfiguredCircularBufferCount ? kBfloat16TileSizeBytes
                                                : kInvalidTileSizeBytes;
}

} // namespace ttwkv7_architecture_check

#if defined(UCK_CHLKC_MATH)
constexpr ckernel::MathFidelity MATH_FIDELITY = ckernel::MathFidelity::HiFi4;
constexpr bool APPROX = false;
#endif

#if !defined(UCK_CHLKC_PACK)
constexpr auto unpack_src_format = ttwkv7_architecture_check::generate_values<
    std::uint8_t, ttwkv7_architecture_check::kCircularBufferCount>(
    ttwkv7_architecture_check::data_format_for_index);
constexpr auto unpack_dst_format = unpack_src_format;
constexpr auto unpack_tile_num_faces = ttwkv7_architecture_check::repeat_value<
    std::uint8_t, ttwkv7_architecture_check::kCircularBufferCount>(
    ttwkv7_architecture_check::kTileFaceCount);
constexpr auto unpack_partial_face = ttwkv7_architecture_check::repeat_value<
    std::uint8_t, ttwkv7_architecture_check::kCircularBufferCount>(0);
constexpr auto unpack_tile_face_r_dim = ttwkv7_architecture_check::repeat_value<
    std::uint8_t, ttwkv7_architecture_check::kCircularBufferCount>(
    ttwkv7_architecture_check::kTileFaceDimension);
constexpr auto unpack_narrow_tile = unpack_partial_face;
constexpr auto unpack_tile_r_dim = ttwkv7_architecture_check::repeat_value<
    std::uint8_t, ttwkv7_architecture_check::kCircularBufferCount>(
    ttwkv7_architecture_check::kTileDimension);
constexpr auto unpack_tile_c_dim = unpack_tile_r_dim;
constexpr auto unpack_tile_size = ttwkv7_architecture_check::generate_values<
    std::uint16_t, ttwkv7_architecture_check::kCircularBufferCount>(
    ttwkv7_architecture_check::tile_size_for_index);
constexpr auto unpack_num_faces_r_dim = ttwkv7_architecture_check::repeat_value<
    std::uint8_t, ttwkv7_architecture_check::kCircularBufferCount>(
    ttwkv7_architecture_check::kTileFacesPerDimension);
constexpr auto unpack_num_faces_c_dim = unpack_num_faces_r_dim;
#endif

#if defined(UCK_CHLKC_MATH) || defined(UCK_CHLKC_PACK) ||                      \
    defined(UCK_CHLKC_UNPACK) || defined(UCK_CHLKC_ISOLATE_SFPU)
constexpr bool DST_ACCUM_MODE = true;
#define DST_SYNC_MODE DstSync::SyncHalf
#endif
