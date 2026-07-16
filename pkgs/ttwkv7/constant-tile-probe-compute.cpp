#include <cstdint>

#include "api/compute/cb_api.h"
#include "api/compute/common.h"
#include "api/compute/compute_kernel_api.h"
#include "api/compute/compute_kernel_hw_startup.h"
#include "api/compute/pack.h"
#include "api/compute/reg_api.h"

namespace {

enum ConstantPattern {
  GM_TRI,
  GM_MSL,
  GM_MLI,
  GM_IDN,
  GM_SEL,
  GM_NCL,
  GM_RWM,
  GM_COUNT,
};

constexpr int kTileWidth = 32;
constexpr int kHalfTileWidth = kTileWidth / 2;
constexpr int kSfpuSubrowCount = kTileWidth;
constexpr int kColumnFaceShift = 3;
constexpr int kRowFaceShift = 4;
constexpr int kRowGroupShift = 1;
constexpr int kRowGroupMask = 3;
constexpr int kRowGroupHeight = 4;
constexpr int kTileIdRowShift = 4;
constexpr int kTileIdColumnMask = kHalfTileWidth - 1;
constexpr int kProbeLengths[] = {1, kTileWidth};
constexpr std::uint32_t kOutputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_16);
constexpr std::uint32_t kOneTile = 1;
constexpr std::uint32_t kDestinationTile = 0;

#ifdef TRISC_MATH
using namespace sfpi;

inline void finish_const_tile_sfpu() {
#if defined(ARCH_BLACKHOLE)
  _llk_math_eltwise_sfpu_done_with_addrmod_reset_();
#elif defined(ARCH_WORMHOLE)
  _llk_math_eltwise_sfpu_done_();
#else
#error "ttWKV7 constant generation requires a reviewed SFPU finalizer"
#endif
}

inline void generate_const_tile(int pattern, int length) {
  _llk_math_eltwise_sfpu_start_(kDestinationTile);
  for (int subrow = 0; subrow < kSfpuSubrowCount; ++subrow) {
    const int column_base =
        ((subrow >> kColumnFaceShift) & 1) * kHalfTileWidth + (subrow & 1);
    const int row_base =
        (subrow >> kRowFaceShift) * kHalfTileWidth +
        ((subrow >> kRowGroupShift) & kRowGroupMask) * kRowGroupHeight;
    vInt tile_id = vConstTileId;
    vInt column = (vConstTileId & kTileIdColumnMask) + column_base;
    vInt row = (tile_id >> kTileIdRowShift) + row_base;
    vFloat value = 0.0F;
    switch (pattern) {
    case GM_TRI:
      v_if(row <= column) { value = 1.0F; }
      v_endif;
      break;
    case GM_MSL:
      v_if(row < length) {
        v_if(column < row) { value = 1.0F; }
        v_endif;
      }
      v_endif;
      break;
    case GM_MLI:
      v_if(row < length) {
        v_if(column < row + 1) { value = 1.0F; }
        v_endif;
      }
      v_endif;
      break;
    case GM_IDN:
      v_if(row == column) { value = 1.0F; }
      v_endif;
      break;
    case GM_SEL:
      v_if(row == length - 1) {
        v_if(column == 0) { value = 1.0F; }
        v_endif;
      }
      v_endif;
      break;
    case GM_NCL:
      v_if(column >= length) { value = 1.0F; }
      v_endif;
      break;
    case GM_RWM:
      v_if(row < length) { value = 1.0F; }
      v_endif;
      break;
    default:
      break;
    }
    dst_reg[subrow] = value;
  }
  finish_const_tile_sfpu();
}
#endif

} // namespace

void kernel_main() {
  compute_kernel_hw_startup(kOutputCb, kOutputCb, kOutputCb);

  for (const int length : kProbeLengths) {
    for (int pattern = GM_TRI; pattern < GM_COUNT; ++pattern) {
      cb_reserve_back(kOutputCb, kOneTile);
      tile_regs_acquire();
      MATH(generate_const_tile(pattern, length));
      tile_regs_commit();
      tile_regs_wait();
      pack_tile(kDestinationTile, kOutputCb);
      tile_regs_release();
      cb_push_back(kOutputCb, kOneTile);
    }
  }
}
