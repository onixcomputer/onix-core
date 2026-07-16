#pragma once

#include <cstdint>

namespace ttwkv7 {

// r[impl onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
constexpr uint32_t kFaceRowBytes = 32;
constexpr uint32_t kRowsPerFace = 16;
constexpr uint32_t kTileRows = 32;
constexpr uint32_t kColumnFaceCount = 2;
constexpr uint32_t kFaceBytes = kRowsPerFace * kFaceRowBytes;
constexpr uint32_t kLastFaceRowOffset = kFaceBytes - kFaceRowBytes;
constexpr uint32_t kBytesPerWord = sizeof(uint32_t);
constexpr uint32_t kWordsPerFaceRow = kFaceRowBytes / kBytesPerWord;
constexpr uint32_t kDramReadAlignmentBytes = NOC_DRAM_READ_ALIGNMENT_BYTES;
constexpr uint32_t kDramReadScratchWords =
    kDramReadAlignmentBytes / kBytesPerWord;

static_assert(kFaceRowBytes % kBytesPerWord == 0);
static_assert(kDramReadAlignmentBytes >= kFaceRowBytes);
static_assert(kDramReadAlignmentBytes <= kColumnFaceCount * kFaceRowBytes);
static_assert(kDramReadAlignmentBytes % kFaceRowBytes == 0);

constexpr uint32_t tile_face_row_offset(uint32_t row, uint32_t column_face) {
  return ((row / kRowsPerFace) * kColumnFaceCount + column_face) * kFaceBytes +
         (row % kRowsPerFace) * kFaceRowBytes;
}

constexpr uint32_t aligned_dram_offset(uint32_t source_offset) {
  return source_offset - source_offset % kDramReadAlignmentBytes;
}

constexpr uint32_t dram_offset_remainder(uint32_t source_offset) {
  return source_offset % kDramReadAlignmentBytes;
}

constexpr bool face_row_plan_is_valid(uint32_t source_offset) {
  const uint32_t aligned_offset = aligned_dram_offset(source_offset);
  const uint32_t remainder = dram_offset_remainder(source_offset);
  return aligned_offset % kDramReadAlignmentBytes == 0 &&
         aligned_offset + remainder == source_offset &&
         remainder + kFaceRowBytes <= kDramReadAlignmentBytes;
}

constexpr bool all_tile_face_row_plans_are_valid() {
  for (uint32_t row = 0; row < kTileRows; ++row) {
    for (uint32_t column_face = 0; column_face < kColumnFaceCount;
         ++column_face) {
      const uint32_t offset = tile_face_row_offset(row, column_face);
      if (!face_row_plan_is_valid(offset) || offset % kFaceRowBytes != 0) {
        return false;
      }
    }
  }
  return true;
}

static_assert(all_tile_face_row_plans_are_valid());
static_assert(face_row_plan_is_valid(0));
static_assert(face_row_plan_is_valid(kFaceRowBytes));
static_assert(face_row_plan_is_valid(kLastFaceRowOffset));
static_assert(face_row_plan_is_valid(kFaceBytes));
static_assert(face_row_plan_is_valid(kFaceBytes + kFaceRowBytes));
static_assert(face_row_plan_is_valid(kFaceBytes + kLastFaceRowOffset));
static_assert(face_row_plan_is_valid(kDramReadAlignmentBytes));
static_assert(!face_row_plan_is_valid(kDramReadAlignmentBytes -
                                      kFaceRowBytes / kBytesPerWord));

FORCE_INLINE void read_dram_face_row(uint64_t aligned_source_noc_address,
                                     uint32_t source_remainder,
                                     uint32_t destination_l1_address,
                                     uint32_t dram_read_scratch_l1_address) {
#ifdef ARCH_BLACKHOLE
  noc_async_read(aligned_source_noc_address, dram_read_scratch_l1_address,
                 kDramReadAlignmentBytes);
  noc_async_read_barrier();
  volatile tt_l1_ptr uint32_t *dram_read_scratch =
      reinterpret_cast<volatile tt_l1_ptr uint32_t *>(
          dram_read_scratch_l1_address);
  volatile tt_l1_ptr uint32_t *destination =
      reinterpret_cast<volatile tt_l1_ptr uint32_t *>(destination_l1_address);
  const uint32_t source_word_offset = source_remainder / kBytesPerWord;
  for (uint32_t word = 0; word < kWordsPerFaceRow; ++word) {
    destination[word] = dram_read_scratch[source_word_offset + word];
  }
#else
  (void)source_remainder;
  (void)dram_read_scratch_l1_address;
  noc_async_read(aligned_source_noc_address, destination_l1_address,
                 kFaceRowBytes);
#endif
}

} // namespace ttwkv7
