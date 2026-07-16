#include <cstdint>

namespace {
constexpr std::uint32_t kWriterInputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_16);
constexpr std::uint32_t kOneTile = 1;
} // namespace

void kernel_main() {
  const std::uint32_t source_address = get_arg_val<std::uint32_t>(0);
  const std::uint32_t tile_count = get_arg_val<std::uint32_t>(1);
  constexpr auto source_args = TensorAccessorArgs<0>();
  const auto source = TensorAccessor(source_args, source_address);

  for (std::uint32_t tile_index = 0; tile_index < tile_count; ++tile_index) {
    cb_reserve_back(kWriterInputCb, kOneTile);
    const std::uint32_t tile_address = get_write_ptr(kWriterInputCb);
    noc_async_read_page(tile_index, source, tile_address);
    noc_async_read_barrier();
    cb_push_back(kWriterInputCb, kOneTile);
  }
}
