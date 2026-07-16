#include <cstdint>

namespace {
constexpr std::uint32_t kReaderOutputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_21);
constexpr std::uint32_t kOneTile = 1;
} // namespace

void kernel_main() {
  const std::uint32_t output_address = get_arg_val<std::uint32_t>(0);
  const std::uint32_t tile_count = get_arg_val<std::uint32_t>(1);
  constexpr auto output_args = TensorAccessorArgs<0>();
  const auto output = TensorAccessor(output_args, output_address);

  for (std::uint32_t tile_index = 0; tile_index < tile_count; ++tile_index) {
    cb_wait_front(kReaderOutputCb, kOneTile);
    const std::uint32_t tile_address = get_read_ptr(kReaderOutputCb);
    noc_async_write_page(tile_index, output, tile_address);
    noc_async_write_barrier();
    cb_pop_front(kReaderOutputCb, kOneTile);
  }
}
