#include <array>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <optional>
#include <string_view>
#include <vector>

#include <tt-metalium/bfloat16.hpp>
#include <tt-metalium/core_coord.hpp>
#include <tt-metalium/distributed.hpp>
#include <tt-metalium/host_api.hpp>
#include <tt-metalium/mesh_device.hpp>
#include <tt-metalium/program.hpp>
#include <tt-metalium/tensor_accessor_args.hpp>
#include <tt-metalium/tilize_utils.hpp>

using namespace tt::tt_metal;

namespace ttwkv7::constant_probe {

constexpr std::uint32_t kTileWidth = 32;
constexpr std::uint32_t kTileHeight = 32;
constexpr std::uint32_t kElementsPerTile = kTileWidth * kTileHeight;
constexpr std::uint32_t kBytesPerTile = sizeof(bfloat16) * kElementsPerTile;
constexpr std::uint32_t kMinimumLength = 1;
constexpr std::uint32_t kMaximumLength = kTileWidth;
constexpr std::uint32_t kCircularBufferTiles = 2;
constexpr std::uint32_t kInvalidArgumentStatus = 2;
constexpr std::uint32_t kProbeFailureStatus = 1;
constexpr std::uint32_t kSuccessStatus = 0;
constexpr std::string_view kSelfTestMode = "self-test";
constexpr std::string_view kProbeMode = "probe";

// Keep this order identical to the device generator's GM_* order.
enum class Pattern : std::uint32_t {
  Tri,
  StrictLower,
  InclusiveLower,
  Identity,
  SelectLast,
  NotColumn,
  RowMask,
  Count,
};

constexpr std::size_t kPatternCount = static_cast<std::size_t>(Pattern::Count);
constexpr std::array<Pattern, kPatternCount> kPatterns = {
    Pattern::Tri,      Pattern::StrictLower, Pattern::InclusiveLower,
    Pattern::Identity, Pattern::SelectLast,  Pattern::NotColumn,
    Pattern::RowMask,
};
constexpr std::array<std::uint32_t, 2> kProbeLengths = {kMinimumLength,
                                                        kMaximumLength};
constexpr std::size_t kProbeTileCount = kPatternCount * kProbeLengths.size();

struct OracleTile {
  std::vector<bfloat16> elements;
};

const char *pattern_name(Pattern pattern) {
  switch (pattern) {
  case Pattern::Tri:
    return "tri";
  case Pattern::StrictLower:
    return "strict-lower";
  case Pattern::InclusiveLower:
    return "inclusive-lower";
  case Pattern::Identity:
    return "identity";
  case Pattern::SelectLast:
    return "select-last";
  case Pattern::NotColumn:
    return "not-column";
  case Pattern::RowMask:
    return "row-mask";
  case Pattern::Count:
    break;
  }
  return "unknown";
}

bool valid_pattern(Pattern pattern) {
  return static_cast<std::size_t>(pattern) < kPatternCount;
}

bool valid_length(std::uint32_t length) {
  return length >= kMinimumLength && length <= kMaximumLength;
}

bool expected_one(Pattern pattern, std::uint32_t length, std::uint32_t row,
                  std::uint32_t column) {
  switch (pattern) {
  case Pattern::Tri:
    return row <= column;
  case Pattern::StrictLower:
    return row < length && column < row;
  case Pattern::InclusiveLower:
    return row < length && column <= row;
  case Pattern::Identity:
    return row == column;
  case Pattern::SelectLast:
    return row == length - 1 && column == 0;
  case Pattern::NotColumn:
    return column >= length;
  case Pattern::RowMask:
    return row < length;
  case Pattern::Count:
    break;
  }
  return false;
}

std::optional<OracleTile> make_oracle_tile(Pattern pattern,
                                           std::uint32_t length) {
  if (!valid_pattern(pattern) || !valid_length(length)) {
    return std::nullopt;
  }

  OracleTile tile;
  tile.elements.reserve(kElementsPerTile);
  for (std::uint32_t row = 0; row < kTileHeight; ++row) {
    for (std::uint32_t column = 0; column < kTileWidth; ++column) {
      tile.elements.emplace_back(
          expected_one(pattern, length, row, column) ? 1.0F : 0.0F);
    }
  }
  return tile;
}

std::size_t count_ones(const OracleTile &tile) {
  std::size_t count = 0;
  for (const bfloat16 value : tile.elements) {
    if (static_cast<float>(value) == 1.0F) {
      ++count;
    }
  }
  return count;
}

bool run_self_tests() {
  constexpr std::array<std::size_t, kPatternCount> kLengthOneCounts = {
      528, 0, 1, 32, 1, 992, 32,
  };
  constexpr std::array<std::size_t, kPatternCount> kLengthMaximumCounts = {
      528, 496, 528, 32, 1, 0, 1024,
  };

  bool passed = true;
  for (std::size_t pattern_index = 0; pattern_index < kPatternCount;
       ++pattern_index) {
    const Pattern pattern = kPatterns[pattern_index];
    const auto length_one = make_oracle_tile(pattern, kMinimumLength);
    const auto length_maximum = make_oracle_tile(pattern, kMaximumLength);
    if (!length_one || !length_maximum) {
      std::fprintf(stderr, "oracle rejected valid pattern %s\n",
                   pattern_name(pattern));
      passed = false;
      continue;
    }
    if (length_one->elements.size() != kElementsPerTile ||
        length_maximum->elements.size() != kElementsPerTile) {
      std::fprintf(stderr, "oracle returned an invalid tile size for %s\n",
                   pattern_name(pattern));
      passed = false;
    }
    if (count_ones(*length_one) != kLengthOneCounts[pattern_index]) {
      std::fprintf(stderr, "length-1 one-count mismatch for %s\n",
                   pattern_name(pattern));
      passed = false;
    }
    if (count_ones(*length_maximum) != kLengthMaximumCounts[pattern_index]) {
      std::fprintf(stderr, "length-32 one-count mismatch for %s\n",
                   pattern_name(pattern));
      passed = false;
    }
  }

  const Pattern invalid_pattern = static_cast<Pattern>(kPatternCount);
  if (make_oracle_tile(invalid_pattern, kMinimumLength).has_value()) {
    std::fprintf(stderr, "oracle accepted an unknown pattern\n");
    passed = false;
  }
  if (make_oracle_tile(Pattern::Identity, kMinimumLength - 1).has_value()) {
    std::fprintf(stderr, "oracle accepted a length below the valid range\n");
    passed = false;
  }
  if (make_oracle_tile(Pattern::Identity, kMaximumLength + 1).has_value()) {
    std::fprintf(stderr, "oracle accepted a length above the valid range\n");
    passed = false;
  }

  return passed;
}

std::shared_ptr<distributed::MeshBuffer>
make_output_buffer(const std::shared_ptr<distributed::MeshDevice> &device) {
  distributed::DeviceLocalBufferConfig local_config{
      .page_size = kBytesPerTile,
      .buffer_type = BufferType::DRAM,
  };
  distributed::ReplicatedBufferConfig replicated_config{
      .size = kBytesPerTile * kProbeTileCount,
  };
  return distributed::MeshBuffer::create(replicated_config, local_config,
                                         device.get());
}

std::vector<float> untilize_one_tile(const std::vector<bfloat16> &raw,
                                     std::size_t tile_index) {
  std::vector<float> tiled(kElementsPerTile);
  const std::size_t offset = tile_index * kElementsPerTile;
  for (std::size_t element_index = 0; element_index < kElementsPerTile;
       ++element_index) {
    tiled[element_index] = static_cast<float>(raw[offset + element_index]);
  }
  return convert_layout(tt::stl::Span<const float>(tiled),
                        std::array<std::uint32_t, 2>{kTileHeight, kTileWidth},
                        TensorLayoutType::TILED_NFACES,
                        TensorLayoutType::LIN_ROW_MAJOR);
}

struct Comparison {
  std::size_t mismatch_count = 0;
  std::size_t first_mismatch = 0;
  float first_expected = 0.0F;
  float first_actual = 0.0F;
};

Comparison compare_tile(const OracleTile &expected,
                        const std::vector<float> &actual) {
  Comparison comparison;
  if (expected.elements.size() != actual.size()) {
    comparison.mismatch_count = expected.elements.size() + actual.size();
    return comparison;
  }

  for (std::size_t element_index = 0; element_index < actual.size();
       ++element_index) {
    const float expected_value =
        static_cast<float>(expected.elements[element_index]);
    if (actual[element_index] != expected_value) {
      if (comparison.mismatch_count == 0) {
        comparison.first_mismatch = element_index;
        comparison.first_expected = expected_value;
        comparison.first_actual = actual[element_index];
      }
      ++comparison.mismatch_count;
    }
  }
  return comparison;
}

bool run_device_probe() {
  constexpr int kDeviceIndex = 0;
  constexpr CoreCoord kCore = {0, 0};
  constexpr auto kOutputCb = tt::CBIndex::c_16;
  constexpr std::string_view kComputeKernel =
      "kernels/ttwkv7_constant_tile_compute.cpp";
  constexpr std::string_view kWriterKernel =
      "kernels/ttwkv7_constant_tile_writer.cpp";

  auto device = distributed::MeshDevice::create_unit_mesh(kDeviceIndex);
  auto &command_queue = device->mesh_command_queue();
  auto output_buffer = make_output_buffer(device);

  Program program = CreateProgram();
  CreateCircularBuffer(
      program, kCore,
      CircularBufferConfig(kCircularBufferTiles * kBytesPerTile,
                           {{kOutputCb, tt::DataFormat::Float16_b}})
          .set_page_size(kOutputCb, kBytesPerTile));

  std::vector<std::uint32_t> writer_compile_args;
  TensorAccessorArgs(*output_buffer).append_to(writer_compile_args);
  const auto writer =
      CreateKernel(program, std::string(kWriterKernel), kCore,
                   DataMovementConfig{
                       .processor = DataMovementProcessor::RISCV_1,
                       .noc = NOC::RISCV_1_default,
                       .compile_args = writer_compile_args,
                   });
  CreateKernel(program, std::string(kComputeKernel), kCore,
               ComputeConfig{
                   .math_fidelity = MathFidelity::HiFi4,
                   .fp32_dest_acc_en = false,
               });
  SetRuntimeArgs(program, writer, kCore,
                 {static_cast<std::uint32_t>(output_buffer->address()),
                  static_cast<std::uint32_t>(kProbeTileCount)});

  distributed::MeshWorkload workload;
  workload.add_program(distributed::MeshCoordinateRange(device->shape()),
                       std::move(program));
  distributed::EnqueueMeshWorkload(command_queue, workload, false);
  distributed::Finish(command_queue);

  std::vector<bfloat16> raw;
  distributed::EnqueueReadMeshBuffer(command_queue, raw, output_buffer, true);

  bool passed = true;
  const std::size_t expected_elements = kProbeTileCount * kElementsPerTile;
  if (raw.size() != expected_elements) {
    std::fprintf(stderr, "probe returned %zu elements; expected %zu\n",
                 raw.size(), expected_elements);
    passed = false;
  } else {
    std::size_t tile_index = 0;
    for (const std::uint32_t length : kProbeLengths) {
      for (const Pattern pattern : kPatterns) {
        const auto expected = make_oracle_tile(pattern, length);
        if (!expected) {
          std::fprintf(stderr, "internal oracle rejected %s at length %u\n",
                       pattern_name(pattern), length);
          passed = false;
          ++tile_index;
          continue;
        }

        const auto actual = untilize_one_tile(raw, tile_index);
        const Comparison comparison = compare_tile(*expected, actual);
        if (comparison.mismatch_count == 0) {
          std::printf("length=%u pattern=%s mismatches=0 PASS\n", length,
                      pattern_name(pattern));
        } else {
          const std::size_t row = comparison.first_mismatch / kTileWidth;
          const std::size_t column = comparison.first_mismatch % kTileWidth;
          std::printf("length=%u pattern=%s mismatches=%zu first=[%zu,%zu] "
                      "expected=%.1f actual=%.8g FAIL\n",
                      length, pattern_name(pattern), comparison.mismatch_count,
                      row, column, comparison.first_expected,
                      comparison.first_actual);
          passed = false;
        }
        ++tile_index;
      }
    }
  }

  if (!device->close()) {
    std::fprintf(stderr, "failed to close the probe mesh device cleanly\n");
    passed = false;
  }
  return passed;
}

void print_usage(const char *program_name) {
  std::fprintf(stderr, "usage: %s self-test|probe\n", program_name);
}

} // namespace ttwkv7::constant_probe

int main(int argc, char **argv) {
  using namespace ttwkv7::constant_probe;

  if (argc != 2) {
    print_usage(argv[0]);
    return kInvalidArgumentStatus;
  }

  const std::string_view mode = argv[1];
  if (mode == kSelfTestMode) {
    const bool passed = run_self_tests();
    std::printf("constant-tile oracle self-test: %s\n",
                passed ? "PASS" : "FAIL");
    return passed ? kSuccessStatus : kProbeFailureStatus;
  }
  if (mode == kProbeMode) {
    try {
      const bool passed = run_device_probe();
      std::printf("constant-tile device probe: %s\n", passed ? "PASS" : "FAIL");
      return passed ? kSuccessStatus : kProbeFailureStatus;
    } catch (const std::exception &error) {
      std::fprintf(stderr, "constant-tile device probe failed: %s\n",
                   error.what());
      return kProbeFailureStatus;
    }
  }

  print_usage(argv[0]);
  return kInvalidArgumentStatus;
}
