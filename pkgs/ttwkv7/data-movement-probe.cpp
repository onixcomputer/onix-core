#include <array>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <memory>
#include <string>
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

namespace ttwkv7::data_movement {

constexpr std::uint32_t kTileWidth = 32;
constexpr std::uint32_t kTileHeight = 32;
constexpr std::uint32_t kElementsPerTile = kTileWidth * kTileHeight;
constexpr std::uint32_t kBytesPerTile = sizeof(bfloat16) * kElementsPerTile;
constexpr std::uint32_t kHeadSize = 64;
constexpr std::uint32_t kHeadCount = 32;
constexpr std::uint32_t kSequenceCount = 1;
constexpr std::uint32_t kSequenceCountPadded = 32;
constexpr std::uint32_t kTokenCount = 1;
constexpr std::uint32_t kTilesPerHeadDimension = kHeadSize / kTileWidth;
constexpr std::uint32_t kHeadTileRows = kHeadCount / kTileHeight;
constexpr std::uint32_t kStateTilesPerHead =
    kTilesPerHeadDimension * kTilesPerHeadDimension;
constexpr std::uint32_t kInputTensorCount = 6;
constexpr std::uint32_t kDecayTensorIndex = 1;
constexpr std::uint32_t kInputTilesPerInstance =
    kInputTensorCount * kTilesPerHeadDimension;
constexpr std::uint32_t kReaderTilesPerInstance =
    kStateTilesPerHead + kInputTilesPerInstance;
constexpr std::uint32_t kInstanceCount = kSequenceCount * kHeadCount;
constexpr std::uint32_t kReaderCaptureTileCount =
    kInstanceCount * kReaderTilesPerInstance;
constexpr std::uint32_t kWriterTilesPerInstance =
    kTilesPerHeadDimension + kStateTilesPerHead;
constexpr std::uint32_t kWriterSourceTileCount =
    kInstanceCount * kWriterTilesPerInstance;
constexpr std::uint32_t kChannelCount = kHeadSize * kHeadCount;
constexpr std::uint32_t kTokenRows = kSequenceCount * kTokenCount;
constexpr std::uint32_t kStateRows = kSequenceCount * kHeadSize;
constexpr std::uint32_t kWriterLogicalRows = kTokenRows + kStateRows;
constexpr std::uint32_t kWriterOutputRows =
    ((kWriterLogicalRows + kTileHeight - 1) / kTileHeight) * kTileHeight;
constexpr std::uint32_t kWriterOutputTileColumns = kChannelCount / kTileWidth;
constexpr std::uint32_t kWriterOutputTileCount =
    (kWriterOutputRows / kTileHeight) * kWriterOutputTileColumns;
constexpr std::uint32_t kStateColumnCount = kHeadSize * kHeadSize * kHeadCount;
constexpr std::uint32_t kStateInputTileCount =
    kSequenceCountPadded * kStateColumnCount / kElementsPerTile;
constexpr std::uint32_t kInputBufferTileCount =
    kSequenceCount * kTokenCount * kHeadTileRows * kTilesPerHeadDimension;
constexpr std::uint32_t kReaderCbCapacityTiles = 32;
constexpr std::uint32_t kWriterCbCapacityTiles = 12;
constexpr std::uint32_t kReaderOutputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_21);
constexpr std::uint32_t kWriterInputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_16);
constexpr std::uint32_t kLogicalDeviceIndex = 0;
constexpr std::uint32_t kOneChunk = 1;
constexpr std::uint32_t kChunkedGroupSize = 2;
constexpr std::uint32_t kDecodeGroupSize = 1;
constexpr std::uint32_t kChunkedTokensPerChunk = kTileHeight;
constexpr std::uint32_t kDecodeTokensPerChunk = 1;
constexpr std::uint32_t kSuccessStatus = 0;
constexpr std::uint32_t kProbeFailureStatus = 1;
constexpr std::uint32_t kInvalidArgumentStatus = 2;
constexpr int kExpectedArgumentCount = 2;
constexpr std::string_view kSelfTestMode = "self-test";
constexpr std::string_view kProbeMode = "probe";
constexpr float kSentinelValue = -3.0F;
constexpr std::uint32_t kTagModulus = 255;
constexpr std::int32_t kTagCenter = 127;
constexpr float kTagScale = 128.0F;
constexpr std::uint32_t kDomainMix = 53;
constexpr std::uint32_t kFirstCoordinateMix = 97;
constexpr std::uint32_t kSecondCoordinateMix = 29;
constexpr std::uint32_t kThirdCoordinateMix = 7;
constexpr std::uint32_t kSampleHead = 15;
constexpr std::uint32_t kSampleRow = 16;
constexpr std::uint32_t kSampleColumn = 31;
constexpr std::uint32_t kLastHead = kHeadCount - 1;
constexpr std::uint32_t kLastDimension = kHeadSize - 1;
constexpr std::size_t kNoMismatch = 0;
constexpr CoreCoord kProbeCore = {0, 0};
constexpr std::string_view kChunkedReader = "kernels/wkv7_reader.cpp";
constexpr std::string_view kDecodeReader = "kernels/wkv7_decodeL_reader.cpp";
constexpr std::string_view kProductionWriter = "kernels/wkv7_writer.cpp";
constexpr std::string_view kCaptureWriter =
    "kernels/ttwkv7_data_movement_capture_writer.cpp";
constexpr std::string_view kSourceReader =
    "kernels/ttwkv7_data_movement_source_reader.cpp";

enum class Path : std::uint32_t {
  Chunked,
  Decode,
};

enum class TagDomain : std::uint32_t {
  Input,
  ReaderState = kInputTensorCount,
  WriterOutput,
  WriterState,
};

struct ExpectedTile {
  std::vector<float> values;
  std::vector<bool> compared;
};

struct Comparison {
  std::size_t mismatch_count = 0;
  std::size_t first_mismatch = 0;
  float first_expected = 0.0F;
  float first_actual = 0.0F;
};

const char *path_name(Path path) {
  switch (path) {
  case Path::Chunked:
    return "chunked";
  case Path::Decode:
    return "decodeL";
  }
  return "unknown";
}

float quantize(float value) { return static_cast<float>(bfloat16(value)); }

float tagged_value(TagDomain domain, std::uint32_t first, std::uint32_t second,
                   std::uint32_t third) {
  const std::uint32_t mixed =
      (static_cast<std::uint32_t>(domain) * kDomainMix +
       first * kFirstCoordinateMix + second * kSecondCoordinateMix +
       third * kThirdCoordinateMix) %
      kTagModulus;
  const std::int32_t centered = static_cast<std::int32_t>(mixed) - kTagCenter;
  return quantize(static_cast<float>(centered) / kTagScale);
}

float input_tag(std::uint32_t tensor, std::uint32_t head,
                std::uint32_t dimension) {
  return tagged_value(TagDomain::Input, tensor, head, dimension);
}

float reader_state_tag(std::uint32_t head, std::uint32_t row,
                       std::uint32_t column) {
  return tagged_value(TagDomain::ReaderState, head, row, column);
}

float writer_output_tag(std::uint32_t head, std::uint32_t dimension) {
  return tagged_value(TagDomain::WriterOutput, head, dimension, 0);
}

float writer_state_tag(std::uint32_t head, std::uint32_t row,
                       std::uint32_t column) {
  return tagged_value(TagDomain::WriterState, head, row, column);
}

std::vector<float> tilize_values(const std::vector<float> &row_major,
                                 std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(row_major),
                        std::array<std::uint32_t, 2>{rows, columns},
                        TensorLayoutType::LIN_ROW_MAJOR,
                        TensorLayoutType::TILED_NFACES);
}

std::vector<float> untilize_values(const std::vector<float> &tiled,
                                   std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(tiled),
                        std::array<std::uint32_t, 2>{rows, columns},
                        TensorLayoutType::TILED_NFACES,
                        TensorLayoutType::LIN_ROW_MAJOR);
}

std::vector<bfloat16> to_bfloat16(const std::vector<float> &values) {
  std::vector<bfloat16> result;
  result.reserve(values.size());
  for (const float value : values) {
    result.emplace_back(value);
  }
  return result;
}

std::vector<float> to_float(const std::vector<bfloat16> &values) {
  std::vector<float> result;
  result.reserve(values.size());
  for (const bfloat16 value : values) {
    result.push_back(static_cast<float>(value));
  }
  return result;
}

ExpectedTile make_state_tile(bool writer, std::uint32_t head,
                             std::uint32_t tile_row,
                             std::uint32_t tile_column) {
  ExpectedTile tile;
  tile.values.reserve(kElementsPerTile);
  tile.compared.assign(kElementsPerTile, true);
  for (std::uint32_t row = 0; row < kTileHeight; ++row) {
    for (std::uint32_t column = 0; column < kTileWidth; ++column) {
      const std::uint32_t global_row = tile_row * kTileHeight + row;
      const std::uint32_t global_column = tile_column * kTileWidth + column;
      tile.values.push_back(
          writer ? writer_state_tag(head, global_row, global_column)
                 : reader_state_tag(head, global_row, global_column));
    }
  }
  return tile;
}

ExpectedTile make_reader_input_tile(Path path, std::uint32_t tensor,
                                    std::uint32_t head,
                                    std::uint32_t dimension_tile) {
  ExpectedTile tile;
  tile.values.reserve(kElementsPerTile);
  tile.compared.reserve(kElementsPerTile);
  const float neutral = tensor == kDecayTensorIndex ? 1.0F : 0.0F;
  for (std::uint32_t row = 0; row < kTileHeight; ++row) {
    for (std::uint32_t column = 0; column < kTileWidth; ++column) {
      if (row == 0) {
        tile.values.push_back(
            input_tag(tensor, head, dimension_tile * kTileWidth + column));
        tile.compared.push_back(true);
      } else {
        tile.values.push_back(neutral);
        tile.compared.push_back(path == Path::Chunked);
      }
    }
  }
  return tile;
}

std::vector<ExpectedTile> expected_reader_tiles(Path path) {
  std::vector<ExpectedTile> tiles;
  tiles.reserve(kReaderCaptureTileCount);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    if (path == Path::Decode) {
      for (std::uint32_t tile_row = 0; tile_row < kTilesPerHeadDimension;
           ++tile_row) {
        for (std::uint32_t tile_column = 0;
             tile_column < kTilesPerHeadDimension; ++tile_column) {
          tiles.push_back(make_state_tile(false, head, tile_row, tile_column));
        }
      }
    }
    for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
      for (std::uint32_t dimension_tile = 0;
           dimension_tile < kTilesPerHeadDimension; ++dimension_tile) {
        tiles.push_back(
            make_reader_input_tile(path, tensor, head, dimension_tile));
      }
    }
    if (path == Path::Chunked) {
      for (std::uint32_t tile_row = 0; tile_row < kTilesPerHeadDimension;
           ++tile_row) {
        for (std::uint32_t tile_column = 0;
             tile_column < kTilesPerHeadDimension; ++tile_column) {
          tiles.push_back(make_state_tile(false, head, tile_row, tile_column));
        }
      }
    }
  }
  return tiles;
}

std::vector<float>
materialize_reader_tiles(const std::vector<ExpectedTile> &tiles) {
  std::vector<float> values;
  values.reserve(tiles.size() * kElementsPerTile);
  for (const ExpectedTile &tile : tiles) {
    values.insert(values.end(), tile.values.begin(), tile.values.end());
  }
  return values;
}

Comparison compare_reader_tiles(const std::vector<ExpectedTile> &expected,
                                const std::vector<float> &actual) {
  Comparison comparison;
  const std::size_t expected_size = expected.size() * kElementsPerTile;
  if (actual.size() != expected_size) {
    comparison.mismatch_count = expected_size + actual.size() + 1;
    return comparison;
  }
  for (std::size_t tile_index = 0; tile_index < expected.size(); ++tile_index) {
    for (std::size_t element_index = 0; element_index < kElementsPerTile;
         ++element_index) {
      if (!expected[tile_index].compared[element_index]) {
        continue;
      }
      const std::size_t global_index =
          tile_index * kElementsPerTile + element_index;
      const float expected_value = expected[tile_index].values[element_index];
      const float actual_value = actual[global_index];
      if (actual_value != expected_value) {
        if (comparison.mismatch_count == kNoMismatch) {
          comparison.first_mismatch = global_index;
          comparison.first_expected = expected_value;
          comparison.first_actual = actual_value;
        }
        ++comparison.mismatch_count;
      }
    }
  }
  return comparison;
}

std::vector<ExpectedTile> writer_source_tiles() {
  std::vector<ExpectedTile> tiles;
  tiles.reserve(kWriterSourceTileCount);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t dimension_tile = 0;
         dimension_tile < kTilesPerHeadDimension; ++dimension_tile) {
      ExpectedTile output;
      output.values.reserve(kElementsPerTile);
      output.compared.assign(kElementsPerTile, true);
      for (std::uint32_t row = 0; row < kTileHeight; ++row) {
        for (std::uint32_t column = 0; column < kTileWidth; ++column) {
          output.values.push_back(
              row == 0 ? writer_output_tag(head,
                                           dimension_tile * kTileWidth + column)
                       : quantize(kSentinelValue));
        }
      }
      tiles.push_back(std::move(output));
    }
    for (std::uint32_t tile_row = 0; tile_row < kTilesPerHeadDimension;
         ++tile_row) {
      for (std::uint32_t tile_column = 0; tile_column < kTilesPerHeadDimension;
           ++tile_column) {
        tiles.push_back(make_state_tile(true, head, tile_row, tile_column));
      }
    }
  }
  return tiles;
}

std::vector<float> expected_writer_matrix() {
  std::vector<float> matrix(static_cast<std::size_t>(kWriterOutputRows) *
                                kChannelCount,
                            quantize(kSentinelValue));
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t dimension = 0; dimension < kHeadSize; ++dimension) {
      matrix[head * kHeadSize + dimension] = writer_output_tag(head, dimension);
    }
    for (std::uint32_t row = 0; row < kHeadSize; ++row) {
      for (std::uint32_t column = 0; column < kHeadSize; ++column) {
        const std::uint32_t destination_row =
            kTokenRows + (head * kHeadSize + row) / kHeadCount;
        const std::uint32_t destination_column =
            ((head * kHeadSize + row) % kHeadCount) * kHeadSize + column;
        matrix[static_cast<std::size_t>(destination_row) * kChannelCount +
               destination_column] = writer_state_tag(head, row, column);
      }
    }
  }
  return matrix;
}

Comparison compare_values(const std::vector<float> &expected,
                          const std::vector<float> &actual) {
  Comparison comparison;
  if (actual.size() != expected.size()) {
    comparison.mismatch_count = expected.size() + actual.size() + 1;
    return comparison;
  }
  for (std::size_t index = 0; index < expected.size(); ++index) {
    if (actual[index] != expected[index]) {
      if (comparison.mismatch_count == kNoMismatch) {
        comparison.first_mismatch = index;
        comparison.first_expected = expected[index];
        comparison.first_actual = actual[index];
      }
      ++comparison.mismatch_count;
    }
  }
  return comparison;
}

bool expect_exact(const char *fixture, const Comparison &comparison) {
  if (comparison.mismatch_count == kNoMismatch) {
    return true;
  }
  std::fprintf(stderr,
               "self-test positive fixture %s mismatched at %zu: expected %.8g "
               "actual %.8g\n",
               fixture, comparison.first_mismatch, comparison.first_expected,
               comparison.first_actual);
  return false;
}

bool expect_rejected(const char *fixture, const Comparison &comparison) {
  if (comparison.mismatch_count != kNoMismatch) {
    return true;
  }
  std::fprintf(stderr, "self-test negative fixture %s was accepted\n", fixture);
  return false;
}

std::vector<float> native_input_matrix(std::uint32_t tensor);
std::vector<float> flat_state_matrix();

bool run_self_tests(bool print_result) {
  bool passed = true;
  for (const Path path : {Path::Chunked, Path::Decode}) {
    const auto expected = expected_reader_tiles(path);
    const auto exact = materialize_reader_tiles(expected);
    if (expected.size() != kReaderCaptureTileCount) {
      std::fprintf(stderr,
                   "reader oracle returned an invalid tile count for %s\n",
                   path_name(path));
      passed = false;
    }
    passed &=
        expect_exact(path_name(path), compare_reader_tiles(expected, exact));

    auto transposed = exact;
    const std::size_t state_tile =
        path == Path::Decode ? 0 : kInputTilesPerInstance;
    const std::size_t state_offset = state_tile * kElementsPerTile;
    std::swap(transposed[state_offset + 1],
              transposed[state_offset + kTileWidth]);
    passed &= expect_rejected("reader-row-column-transpose",
                              compare_reader_tiles(expected, transposed));

    auto permuted = exact;
    for (std::size_t element = 0; element < kElementsPerTile; ++element) {
      std::swap(permuted[element], permuted[kElementsPerTile + element]);
    }
    passed &= expect_rejected("reader-tile-permutation",
                              compare_reader_tiles(expected, permuted));

    auto dropped = exact;
    dropped.resize(dropped.size() - kElementsPerTile);
    passed &=
        expect_rejected("reader-drop", compare_reader_tiles(expected, dropped));

    auto duplicated = exact;
    duplicated.insert(duplicated.end(), exact.begin(),
                      exact.begin() + kElementsPerTile);
    passed &= expect_rejected("reader-duplicate",
                              compare_reader_tiles(expected, duplicated));
  }

  for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
    const auto input = native_input_matrix(tensor);
    if (input.size() != kHeadCount * kHeadSize ||
        input[kSampleHead * kHeadSize + kSampleRow] !=
            input_tag(tensor, kSampleHead, kSampleRow) ||
        input[kLastHead * kHeadSize + kLastDimension] !=
            input_tag(tensor, kLastHead, kLastDimension)) {
      std::fprintf(stderr,
                   "native input source layout mismatch for tensor %u\n",
                   tensor);
      passed = false;
    }
  }

  const auto state_input = flat_state_matrix();
  const std::size_t first_padded_state = kStateColumnCount;
  if (state_input.size() !=
          static_cast<std::size_t>(kSequenceCountPadded) * kStateColumnCount ||
      state_input[kSampleHead * kHeadSize * kHeadSize + kSampleRow * kHeadSize +
                  kSampleColumn] !=
          reader_state_tag(kSampleHead, kSampleRow, kSampleColumn) ||
      state_input[first_padded_state] != quantize(kSentinelValue)) {
    std::fprintf(stderr, "flat state source layout mismatch\n");
    passed = false;
  }

  const auto writer_source = writer_source_tiles();
  if (writer_source.size() != kWriterSourceTileCount ||
      writer_source[0].values[0] != writer_output_tag(0, 0) ||
      writer_source[kTilesPerHeadDimension].values[0] !=
          writer_state_tag(0, 0, 0) ||
      writer_source[kWriterTilesPerInstance].values[0] !=
          writer_output_tag(1, 0)) {
    std::fprintf(stderr, "writer source cadence mismatch\n");
    passed = false;
  }

  const auto writer_expected = expected_writer_matrix();
  const std::size_t known_state_index =
      static_cast<std::size_t>(
          kTokenRows + (kSampleHead * kHeadSize + kSampleRow) / kHeadCount) *
          kChannelCount +
      ((kSampleHead * kHeadSize + kSampleRow) % kHeadCount) * kHeadSize +
      kSampleColumn;
  const std::size_t first_sentinel =
      static_cast<std::size_t>(kWriterLogicalRows) * kChannelCount;
  if (writer_expected.size() !=
          static_cast<std::size_t>(kWriterOutputRows) * kChannelCount ||
      writer_expected[kLastHead * kHeadSize + kLastDimension] !=
          writer_output_tag(kLastHead, kLastDimension) ||
      writer_expected[known_state_index] !=
          writer_state_tag(kSampleHead, kSampleRow, kSampleColumn) ||
      writer_expected[first_sentinel] != quantize(kSentinelValue)) {
    std::fprintf(stderr, "writer destination oracle mapping mismatch\n");
    passed = false;
  }
  passed &= expect_exact("writer-exact",
                         compare_values(writer_expected, writer_expected));

  auto writer_transposed = writer_expected;
  const std::size_t first_state =
      static_cast<std::size_t>(kTokenRows) * kChannelCount;
  std::swap(writer_transposed[first_state + 1],
            writer_transposed[first_state + kChannelCount]);
  passed &= expect_rejected("writer-row-column-transpose",
                            compare_values(writer_expected, writer_transposed));

  auto writer_permuted = writer_expected;
  for (std::size_t element = 0; element < kTileWidth; ++element) {
    std::swap(writer_permuted[element], writer_permuted[kTileWidth + element]);
  }
  passed &= expect_rejected("writer-tile-permutation",
                            compare_values(writer_expected, writer_permuted));

  auto wrong_scatter = writer_expected;
  wrong_scatter[first_state] = writer_output_tag(0, 0);
  passed &= expect_rejected("writer-wrong-scatter",
                            compare_values(writer_expected, wrong_scatter));

  auto sentinel_overwrite = writer_expected;
  sentinel_overwrite[first_sentinel] = 0.0F;
  passed &=
      expect_rejected("writer-sentinel-overwrite",
                      compare_values(writer_expected, sentinel_overwrite));

  if (input_tag(0, 0, 0) == input_tag(1, 0, 0) ||
      reader_state_tag(0, 0, 0) == writer_state_tag(0, 0, 0)) {
    std::fprintf(stderr, "tag domains are not separated\n");
    passed = false;
  }

  if (print_result) {
    std::printf("data-movement oracle self-test: %s\n",
                passed ? "PASS" : "FAIL");
  }
  return passed;
}

std::shared_ptr<distributed::MeshBuffer>
make_buffer(const std::shared_ptr<distributed::MeshDevice> &device,
            std::uint32_t tile_count) {
  distributed::DeviceLocalBufferConfig local_config{
      .page_size = kBytesPerTile,
      .buffer_type = BufferType::DRAM,
  };
  distributed::ReplicatedBufferConfig replicated_config{
      .size = static_cast<std::uint64_t>(kBytesPerTile) * tile_count,
  };
  return distributed::MeshBuffer::create(replicated_config, local_config,
                                         device.get());
}

void make_circular_buffer(Program &program, std::uint32_t cb,
                          std::uint32_t tile_capacity) {
  CircularBufferConfig config(
      tile_capacity * kBytesPerTile,
      {{static_cast<tt::CBIndex>(cb), tt::DataFormat::Float16_b}});
  config.set_page_size(static_cast<tt::CBIndex>(cb), kBytesPerTile);
  CreateCircularBuffer(program, kProbeCore, config);
}

std::vector<float> native_input_matrix(std::uint32_t tensor) {
  std::vector<float> matrix;
  matrix.reserve(kHeadCount * kHeadSize);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t dimension = 0; dimension < kHeadSize; ++dimension) {
      matrix.push_back(input_tag(tensor, head, dimension));
    }
  }
  return matrix;
}

std::vector<float> flat_state_matrix() {
  std::vector<float> matrix(static_cast<std::size_t>(kSequenceCountPadded) *
                                kStateColumnCount,
                            quantize(kSentinelValue));
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t row = 0; row < kHeadSize; ++row) {
      for (std::uint32_t column = 0; column < kHeadSize; ++column) {
        const std::size_t index =
            static_cast<std::size_t>(head) * kHeadSize * kHeadSize +
            row * kHeadSize + column;
        matrix[index] = reader_state_tag(head, row, column);
      }
    }
  }
  return matrix;
}

std::vector<float> untilize_raw_tiles(const std::vector<bfloat16> &raw) {
  std::vector<float> result;
  if (raw.size() % kElementsPerTile != 0) {
    return result;
  }
  result.reserve(raw.size());
  const auto tiled = to_float(raw);
  const std::size_t tile_count = raw.size() / kElementsPerTile;
  for (std::size_t tile_index = 0; tile_index < tile_count; ++tile_index) {
    std::vector<float> one_tile(kElementsPerTile);
    const std::size_t offset = tile_index * kElementsPerTile;
    for (std::size_t element = 0; element < kElementsPerTile; ++element) {
      one_tile[element] = tiled[offset + element];
    }
    auto row_major = untilize_values(one_tile, kTileHeight, kTileWidth);
    result.insert(result.end(), row_major.begin(), row_major.end());
  }
  return result;
}

Comparison
run_reader_capture(const std::shared_ptr<distributed::MeshDevice> &device,
                   Path path) {
  auto &queue = device->mesh_command_queue();
  std::array<std::shared_ptr<distributed::MeshBuffer>, kInputTensorCount>
      inputs;
  for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
    inputs[tensor] = make_buffer(device, kInputBufferTileCount);
    const auto tiled =
        tilize_values(native_input_matrix(tensor), kHeadCount, kHeadSize);
    distributed::EnqueueWriteMeshBuffer(queue, inputs[tensor],
                                        to_bfloat16(tiled), false);
  }

  auto state = make_buffer(device, kStateInputTileCount);
  const auto tiled_state = tilize_values(
      flat_state_matrix(), kSequenceCountPadded, kStateColumnCount);
  distributed::EnqueueWriteMeshBuffer(queue, state, to_bfloat16(tiled_state),
                                      false);
  auto capture = make_buffer(device, kReaderCaptureTileCount);

  Program program = CreateProgram();
  make_circular_buffer(program, kReaderOutputCb, kReaderCbCapacityTiles);

  std::vector<std::uint32_t> reader_compile_args;
  TensorAccessorArgs(*inputs.front()).append_to(reader_compile_args);
  TensorAccessorArgs(*state).append_to(reader_compile_args);
  const auto reader = CreateKernel(
      program,
      std::string(path == Path::Chunked ? kChunkedReader : kDecodeReader),
      kProbeCore,
      DataMovementConfig{.processor = DataMovementProcessor::RISCV_0,
                         .noc = NOC::RISCV_0_default,
                         .compile_args = reader_compile_args});

  std::vector<std::uint32_t> capture_compile_args;
  TensorAccessorArgs(*capture).append_to(capture_compile_args);
  const auto capture_writer = CreateKernel(
      program, std::string(kCaptureWriter), kProbeCore,
      DataMovementConfig{.processor = DataMovementProcessor::RISCV_1,
                         .noc = NOC::RISCV_1_default,
                         .compile_args = capture_compile_args});

  std::vector<std::uint32_t> reader_args{kHeadCount, kTokenCount,
                                         kTilesPerHeadDimension, kHeadTileRows,
                                         kSequenceCount};
  for (const auto &input : inputs) {
    reader_args.push_back(static_cast<std::uint32_t>(input->address()));
  }
  reader_args.push_back(static_cast<std::uint32_t>(state->address()));
  reader_args.push_back(kTokenCount);
  reader_args.push_back(0);
  reader_args.push_back(0);
  reader_args.push_back(kOneChunk);
  reader_args.push_back(0);
  reader_args.push_back(kInstanceCount);
  SetRuntimeArgs(program, reader, kProbeCore, reader_args);
  SetRuntimeArgs(program, capture_writer, kProbeCore,
                 {static_cast<std::uint32_t>(capture->address()),
                  kReaderCaptureTileCount});

  distributed::MeshWorkload workload;
  workload.add_program(distributed::MeshCoordinateRange(device->shape()),
                       std::move(program));
  distributed::EnqueueMeshWorkload(queue, workload, false);
  distributed::Finish(queue);

  std::vector<bfloat16> raw;
  distributed::EnqueueReadMeshBuffer(queue, raw, capture, true);
  return compare_reader_tiles(expected_reader_tiles(path),
                              untilize_raw_tiles(raw));
}

std::vector<float> materialize_tiled_writer_source() {
  std::vector<float> tiled;
  tiled.reserve(kWriterSourceTileCount * kElementsPerTile);
  for (const ExpectedTile &tile : writer_source_tiles()) {
    const auto one_tile = tilize_values(tile.values, kTileHeight, kTileWidth);
    tiled.insert(tiled.end(), one_tile.begin(), one_tile.end());
  }
  return tiled;
}

Comparison
run_writer_scatter(const std::shared_ptr<distributed::MeshDevice> &device,
                   Path path) {
  auto &queue = device->mesh_command_queue();
  auto source = make_buffer(device, kWriterSourceTileCount);
  distributed::EnqueueWriteMeshBuffer(
      queue, source, to_bfloat16(materialize_tiled_writer_source()), false);

  auto output = make_buffer(device, kWriterOutputTileCount);
  const std::vector<float> initial_matrix(
      static_cast<std::size_t>(kWriterOutputRows) * kChannelCount,
      quantize(kSentinelValue));
  distributed::EnqueueWriteMeshBuffer(
      queue, output,
      to_bfloat16(
          tilize_values(initial_matrix, kWriterOutputRows, kChannelCount)),
      false);

  Program program = CreateProgram();
  make_circular_buffer(program, kWriterInputCb, kWriterCbCapacityTiles);

  std::vector<std::uint32_t> source_compile_args;
  TensorAccessorArgs(*source).append_to(source_compile_args);
  const auto source_reader = CreateKernel(
      program, std::string(kSourceReader), kProbeCore,
      DataMovementConfig{.processor = DataMovementProcessor::RISCV_0,
                         .noc = NOC::RISCV_0_default,
                         .compile_args = source_compile_args});

  std::vector<std::uint32_t> writer_compile_args;
  TensorAccessorArgs(*output).append_to(writer_compile_args);
  const auto writer = CreateKernel(
      program, std::string(kProductionWriter), kProbeCore,
      DataMovementConfig{.processor = DataMovementProcessor::RISCV_1,
                         .noc = NOC::RISCV_1_default,
                         .compile_args = writer_compile_args});

  SetRuntimeArgs(
      program, source_reader, kProbeCore,
      {static_cast<std::uint32_t>(source->address()), kWriterSourceTileCount});
  const std::uint32_t tokens_per_chunk =
      path == Path::Chunked ? kChunkedTokensPerChunk : kDecodeTokensPerChunk;
  const std::uint32_t group_size =
      path == Path::Chunked ? kChunkedGroupSize : kDecodeGroupSize;
  SetRuntimeArgs(program, writer, kProbeCore,
                 {static_cast<std::uint32_t>(output->address()), 0,
                  kInstanceCount, kInstanceCount, kOneChunk, kHeadCount,
                  kTilesPerHeadDimension, kWriterOutputTileColumns, kTokenRows,
                  kTokenCount, tokens_per_chunk, group_size});

  distributed::MeshWorkload workload;
  workload.add_program(distributed::MeshCoordinateRange(device->shape()),
                       std::move(program));
  distributed::EnqueueMeshWorkload(queue, workload, false);
  distributed::Finish(queue);

  std::vector<bfloat16> raw;
  distributed::EnqueueReadMeshBuffer(queue, raw, output, true);
  const auto actual =
      untilize_values(to_float(raw), kWriterOutputRows, kChannelCount);
  return compare_values(expected_writer_matrix(), actual);
}

void print_record(Path path, const char *phase, const Comparison &comparison) {
  if (comparison.mismatch_count == kNoMismatch) {
    std::printf("path=%s phase=%s mismatches=0 PASS\n", path_name(path), phase);
    return;
  }
  std::printf("path=%s phase=%s mismatches=%zu first=%zu expected=%.8g "
              "actual=%.8g FAIL\n",
              path_name(path), phase, comparison.mismatch_count,
              comparison.first_mismatch, comparison.first_expected,
              comparison.first_actual);
}

bool run_device_probe() {
  auto device = distributed::MeshDevice::create_unit_mesh(kLogicalDeviceIndex);
  bool passed = true;
  for (const Path path : {Path::Chunked, Path::Decode}) {
    const Comparison comparison = run_reader_capture(device, path);
    print_record(path, "reader-capture", comparison);
    passed &= comparison.mismatch_count == kNoMismatch;
  }
  for (const Path path : {Path::Chunked, Path::Decode}) {
    const Comparison comparison = run_writer_scatter(device, path);
    print_record(path, "writer-scatter", comparison);
    passed &= comparison.mismatch_count == kNoMismatch;
  }
  if (!device->close()) {
    std::fprintf(stderr,
                 "failed to close the data-movement mesh device cleanly\n");
    passed = false;
  }
  return passed;
}

void print_usage(const char *program_name) {
  std::fprintf(stderr, "usage: %s self-test|probe\n", program_name);
}

} // namespace ttwkv7::data_movement

int main(int argc, char **argv) {
  using namespace ttwkv7::data_movement;
  if (argc != kExpectedArgumentCount) {
    print_usage(argv[0]);
    return kInvalidArgumentStatus;
  }

  const std::string_view mode = argv[1];
  if (mode == kSelfTestMode) {
    return run_self_tests(true) ? kSuccessStatus : kProbeFailureStatus;
  }
  if (mode == kProbeMode) {
    if (!run_self_tests(false)) {
      std::fprintf(stderr, "data-movement oracle preflight failed\n");
      return kProbeFailureStatus;
    }
    try {
      const bool passed = run_device_probe();
      std::printf("data-movement device probe: %s\n", passed ? "PASS" : "FAIL");
      return passed ? kSuccessStatus : kProbeFailureStatus;
    } catch (const std::exception &error) {
      std::fprintf(stderr, "data-movement device probe failed: %s\n",
                   error.what());
      return kProbeFailureStatus;
    }
  }

  print_usage(argv[0]);
  return kInvalidArgumentStatus;
}
