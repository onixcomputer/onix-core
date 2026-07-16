#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <filesystem>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
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
constexpr std::uint32_t kFaceWidth = 16;
constexpr std::uint32_t kFaceCount = kTileWidth / kFaceWidth;
constexpr std::size_t kMatrixRank = 2;
constexpr std::uint32_t kHeadSize = 64;
constexpr std::uint32_t kHeadCount = 32;
constexpr std::uint32_t kSequenceCount = 1;
constexpr std::uint32_t kSequenceCountPadded = 32;
constexpr std::uint32_t kPartialTokenCount = 1;
constexpr std::uint32_t kFullChunkTokenCount = 32;
constexpr std::uint32_t kChunkSize = kTileHeight;
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
constexpr std::uint32_t kWriterTokenRows = kSequenceCount * kPartialTokenCount;
constexpr std::uint32_t kStateRows = kSequenceCount * kHeadSize;
constexpr std::uint32_t kWriterLogicalRows = kWriterTokenRows + kStateRows;
constexpr std::uint32_t kWriterOutputRows =
    ((kWriterLogicalRows + kTileHeight - 1) / kTileHeight) * kTileHeight;
constexpr std::uint32_t kWriterOutputTileColumns = kChannelCount / kTileWidth;
constexpr std::uint32_t kWriterOutputTileCount =
    (kWriterOutputRows / kTileHeight) * kWriterOutputTileColumns;
constexpr std::uint32_t kStateColumnCount = kHeadSize * kHeadSize * kHeadCount;
constexpr std::uint32_t kStateInputTileCount =
    kSequenceCountPadded * kStateColumnCount / kElementsPerTile;
constexpr std::uint32_t kExpectedStateInputTileCount = 4096;
constexpr std::uint32_t kMaximumControlTileCount = kStateInputTileCount;
constexpr std::uint32_t kReaderCbCapacityTiles = 32;
constexpr std::uint32_t kWriterCbCapacityTiles = 12;
constexpr std::uint32_t kControlTileCount = 8;
constexpr std::uint32_t kReaderOutputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_21);
constexpr std::uint32_t kWriterInputCb =
    static_cast<std::uint32_t>(tt::CBIndex::c_16);
constexpr std::uint32_t kLogicalDeviceIndex = 0;
constexpr std::uint32_t kOneChunk = 1;
constexpr std::uint32_t kChunkedGroupSize = 2;
constexpr std::uint32_t kDecodeGroupSize = 1;
constexpr std::uint32_t kChunkedTokensPerChunk = kChunkSize;
constexpr std::uint32_t kDecodeTokensPerChunk = 1;
constexpr std::uint32_t kReaderRuntimeArgumentCount = 18;
constexpr std::size_t kReaderCaseCount = 3;
constexpr std::size_t kDecodeCaseIndex = 0;
constexpr std::size_t kChunkedPartialCaseIndex = 1;
constexpr std::size_t kChunkedFullCaseIndex = 2;
constexpr std::size_t kArtifactFixtureElementCount = kFaceCount * kFaceCount;
constexpr std::size_t kControlRecordCount = 1 + kInputTensorCount + 1;
constexpr std::size_t kWriterRecordCount = 2;
constexpr std::size_t kFutureRecordCount =
    kControlRecordCount + kReaderCaseCount + kWriterRecordCount;
constexpr std::size_t kReviewedFutureRecordCount = 13;
constexpr float kArtifactFixtureValue = 0.5F;
constexpr std::uint32_t kSuccessStatus = 0;
constexpr std::uint32_t kProbeFailureStatus = 1;
constexpr std::uint32_t kInvalidArgumentStatus = 2;
constexpr int kExpectedArgumentCount = 2;
constexpr int kArtifactSelfTestArgumentCount = 3;
constexpr int kArtifactRootArgumentIndex = 2;
constexpr std::string_view kSelfTestMode = "self-test";
constexpr std::string_view kArtifactSelfTestMode = "artifact-self-test";
constexpr std::string_view kProbeMode = "probe";
constexpr std::string_view kArtifactDirectoryName = "ttwkv7-data-movement";
constexpr std::string_view kManifestFilename = "manifest.tsv";
constexpr float kSentinelValue = -3.0F;
constexpr std::uint32_t kTagModulus = 255;
constexpr std::int32_t kTagCenter = 127;
constexpr float kTagScale = 128.0F;
constexpr std::uint32_t kDomainMix = 53;
constexpr std::uint32_t kFirstCoordinateMix = 97;
constexpr std::uint32_t kSecondCoordinateMix = 29;
constexpr std::uint32_t kThirdCoordinateMix = 7;
constexpr std::uint32_t kFourthCoordinateMix = 43;
constexpr std::uint32_t kSampleToken = 17;
constexpr std::uint32_t kSampleHead = 15;
constexpr std::uint32_t kSampleRow = 16;
constexpr std::uint32_t kSampleColumn = 31;
constexpr std::uint32_t kLastToken = kFullChunkTokenCount - 1;
constexpr std::uint32_t kLastHead = kHeadCount - 1;
constexpr std::uint32_t kLastDimension = kHeadSize - 1;
constexpr std::uint32_t kFixtureInputAddressBase = 0x1000;
constexpr std::uint32_t kFixtureInputAddressStride = 0x100;
constexpr std::uint32_t kFixtureStateAddress = 0x7000;
constexpr std::size_t kNoMismatch = 0;
constexpr CoreCoord kProbeCore = {0, 0};
constexpr std::string_view kChunkedReader = "kernels/wkv7_reader.cpp";
constexpr std::string_view kDecodeReader = "kernels/wkv7_decodeL_reader.cpp";
constexpr std::string_view kProductionWriter = "kernels/wkv7_writer.cpp";
constexpr std::string_view kCaptureWriter =
    "kernels/ttwkv7_data_movement_capture_writer.cpp";
constexpr std::string_view kCaptureSourceReader =
    "kernels/ttwkv7_data_movement_capture_source_reader.cpp";
constexpr std::string_view kWriterSourceReader =
    "kernels/ttwkv7_data_movement_source_reader.cpp";

static_assert(kChunkSize == kTileHeight);
static_assert(kStateInputTileCount == kExpectedStateInputTileCount);
static_assert(kFutureRecordCount == kReviewedFutureRecordCount);

enum class Path : std::uint32_t {
  Chunked,
  Decode,
};

enum class ReaderCaseKind : std::uint32_t {
  DecodeL1,
  ChunkedPartialL1,
  ChunkedFullL32,
};

enum class ReaderRegion : std::uint32_t {
  Input,
  State,
};

enum class TagDomain : std::uint32_t {
  Input,
  ReaderState,
  WriterOutput,
  WriterState,
  CaptureControl,
};

enum class InputIndex : std::size_t {
  Input0 = 0,
  Input1 = 1,
  Input2 = 2,
  Input3 = 3,
  Input4 = 4,
  Input5 = 5,
};

enum class ReaderArgIndex : std::size_t {
  HeadCount = 0,
  KernelLength = 1,
  TilesPerHeadDimension = 2,
  HeadTileRows = 3,
  SequenceCount = 4,
  Input0 = 5,
  Input1 = 6,
  Input2 = 7,
  Input3 = 8,
  Input4 = 9,
  Input5 = 10,
  State = 11,
  RealLengthOrUnused = 12,
  SelectorOrUnused = 13,
  ConstantsOrUnused = 14,
  ChunkCount = 15,
  InstanceStart = 16,
  InstanceEnd = 17,
};

struct ReaderCase {
  ReaderCaseKind kind;
  Path path;
  std::string_view name;
  std::uint32_t kernel_length;
  std::uint32_t real_token_count;
  std::uint32_t chunk_count;
};

constexpr std::array<ReaderCase, kReaderCaseCount> kReaderCases = {{
    {ReaderCaseKind::DecodeL1, Path::Decode, "decode-L1", kPartialTokenCount,
     kPartialTokenCount, kOneChunk},
    {ReaderCaseKind::ChunkedPartialL1, Path::Chunked, "chunked-partial-L1",
     kChunkSize, kPartialTokenCount, kOneChunk},
    {ReaderCaseKind::ChunkedFullL32, Path::Chunked, "chunked-full-L32",
     kChunkSize, kFullChunkTokenCount, kOneChunk},
}};

static_assert(kReaderCases[kDecodeCaseIndex].kernel_length ==
              kPartialTokenCount);
static_assert(kReaderCases[kChunkedPartialCaseIndex].kernel_length ==
              kChunkSize);
static_assert(kReaderCases[kChunkedPartialCaseIndex].real_token_count ==
              kPartialTokenCount);
static_assert(kReaderCases[kChunkedFullCaseIndex].kernel_length == kChunkSize);
static_assert(kReaderCases[kChunkedFullCaseIndex].real_token_count ==
              kFullChunkTokenCount);

constexpr bool reader_case_is_valid(const ReaderCase &reader_case) {
  if (reader_case.chunk_count != kOneChunk) {
    return false;
  }
  switch (reader_case.kind) {
  case ReaderCaseKind::DecodeL1:
    return reader_case.path == Path::Decode &&
           reader_case.kernel_length == kPartialTokenCount &&
           reader_case.real_token_count == kPartialTokenCount;
  case ReaderCaseKind::ChunkedPartialL1:
    return reader_case.path == Path::Chunked &&
           reader_case.kernel_length == kChunkSize &&
           reader_case.real_token_count == kPartialTokenCount;
  case ReaderCaseKind::ChunkedFullL32:
    return reader_case.path == Path::Chunked &&
           reader_case.kernel_length == kChunkSize &&
           reader_case.real_token_count == kFullChunkTokenCount;
  }
  return false;
}

constexpr bool control_tile_count_is_valid(std::uint32_t tile_count) {
  return tile_count > 0 && tile_count <= kMaximumControlTileCount;
}

static_assert(reader_case_is_valid(kReaderCases[kDecodeCaseIndex]));
static_assert(reader_case_is_valid(kReaderCases[kChunkedPartialCaseIndex]));
static_assert(reader_case_is_valid(kReaderCases[kChunkedFullCaseIndex]));
static_assert(control_tile_count_is_valid(kMaximumControlTileCount));
static_assert(!control_tile_count_is_valid(0));

struct ReaderAddresses {
  std::array<std::uint32_t, kInputTensorCount> inputs{};
  std::uint32_t state = 0;
};

struct ReaderRuntimeArguments {
  std::uint32_t head_count;
  std::uint32_t kernel_length;
  std::uint32_t tiles_per_head_dimension;
  std::uint32_t head_tile_rows;
  std::uint32_t sequence_count;
  ReaderAddresses addresses;
  std::uint32_t real_length_or_unused;
  std::uint32_t selector_or_unused;
  std::uint32_t constants_or_unused;
  std::uint32_t chunk_count;
  std::uint32_t instance_start;
  std::uint32_t instance_end;
};

struct ExpectedTile {
  std::vector<float> values;
  std::vector<bool> compared;
  ReaderRegion region = ReaderRegion::State;
  std::uint32_t head = 0;
};

struct Comparison {
  std::size_t mismatch_count = 0;
  std::size_t first_mismatch = 0;
  float first_expected = 0.0F;
  float first_actual = 0.0F;
};

struct ReaderComparison {
  Comparison summary;
  std::size_t input_mismatches = 0;
  std::size_t state_mismatches = 0;
  std::size_t mismatched_tiles = 0;
  std::array<std::size_t, kTileHeight> row_mismatches{};
  std::array<std::size_t, kFaceCount> face_mismatches{};
  std::array<std::size_t, kHeadCount> head_mismatches{};
};

struct WorkloadCapture {
  std::vector<bfloat16> raw;
  std::vector<std::uint32_t> producer_args;
  std::vector<std::uint32_t> consumer_args;
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

constexpr std::size_t input_index(InputIndex index) {
  return static_cast<std::size_t>(index);
}

constexpr std::size_t reader_arg_index(ReaderArgIndex index) {
  return static_cast<std::size_t>(index);
}

static_assert(reader_arg_index(ReaderArgIndex::InstanceEnd) + 1 ==
              kReaderRuntimeArgumentCount);

float quantize(float value) { return static_cast<float>(bfloat16(value)); }

float tagged_value(TagDomain domain, std::uint32_t first, std::uint32_t second,
                   std::uint32_t third, std::uint32_t fourth) {
  const std::uint32_t mixed =
      (static_cast<std::uint32_t>(domain) * kDomainMix +
       first * kFirstCoordinateMix + second * kSecondCoordinateMix +
       third * kThirdCoordinateMix + fourth * kFourthCoordinateMix) %
      kTagModulus;
  const std::int32_t centered = static_cast<std::int32_t>(mixed) - kTagCenter;
  return quantize(static_cast<float>(centered) / kTagScale);
}

float input_tag(std::uint32_t tensor, std::uint32_t token, std::uint32_t head,
                std::uint32_t dimension) {
  return tagged_value(TagDomain::Input, tensor, token, head, dimension);
}

float reader_state_tag(std::uint32_t head, std::uint32_t row,
                       std::uint32_t column) {
  return tagged_value(TagDomain::ReaderState, head, row, column, 0);
}

float writer_output_tag(std::uint32_t head, std::uint32_t dimension) {
  return tagged_value(TagDomain::WriterOutput, head, dimension, 0, 0);
}

float writer_state_tag(std::uint32_t head, std::uint32_t row,
                       std::uint32_t column) {
  return tagged_value(TagDomain::WriterState, head, row, column, 0);
}

float capture_control_tag(std::uint32_t tile, std::uint32_t row,
                          std::uint32_t column) {
  return tagged_value(TagDomain::CaptureControl, tile, row, column, 0);
}

std::vector<float> tilize_values(const std::vector<float> &row_major,
                                 std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(row_major),
                        std::array<std::uint32_t, kMatrixRank>{rows, columns},
                        TensorLayoutType::LIN_ROW_MAJOR,
                        TensorLayoutType::TILED_NFACES);
}

std::vector<float> untilize_values(const std::vector<float> &tiled,
                                   std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(tiled),
                        std::array<std::uint32_t, kMatrixRank>{rows, columns},
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

ReaderRuntimeArguments
make_reader_runtime_arguments(const ReaderCase &reader_case,
                              const ReaderAddresses &addresses) {
  return ReaderRuntimeArguments{
      .head_count = kHeadCount,
      .kernel_length = reader_case.kernel_length,
      .tiles_per_head_dimension = kTilesPerHeadDimension,
      .head_tile_rows = kHeadTileRows,
      .sequence_count = kSequenceCount,
      .addresses = addresses,
      .real_length_or_unused =
          reader_case.path == Path::Chunked ? reader_case.real_token_count : 0,
      .selector_or_unused = 0,
      .constants_or_unused = 0,
      .chunk_count = reader_case.chunk_count,
      .instance_start = 0,
      .instance_end = kInstanceCount,
  };
}

std::uint32_t input_address(const ReaderAddresses &addresses,
                            InputIndex index) {
  return addresses.inputs[input_index(index)];
}

std::array<std::uint32_t, kReaderRuntimeArgumentCount>
serialize_reader_runtime_arguments(const ReaderRuntimeArguments &arguments) {
  return {
      arguments.head_count,
      arguments.kernel_length,
      arguments.tiles_per_head_dimension,
      arguments.head_tile_rows,
      arguments.sequence_count,
      input_address(arguments.addresses, InputIndex::Input0),
      input_address(arguments.addresses, InputIndex::Input1),
      input_address(arguments.addresses, InputIndex::Input2),
      input_address(arguments.addresses, InputIndex::Input3),
      input_address(arguments.addresses, InputIndex::Input4),
      input_address(arguments.addresses, InputIndex::Input5),
      arguments.addresses.state,
      arguments.real_length_or_unused,
      arguments.selector_or_unused,
      arguments.constants_or_unused,
      arguments.chunk_count,
      arguments.instance_start,
      arguments.instance_end,
  };
}

std::array<std::uint32_t, kReaderRuntimeArgumentCount>
expected_reader_runtime_fixture(const ReaderCase &reader_case,
                                const ReaderAddresses &addresses) {
  switch (reader_case.kind) {
  case ReaderCaseKind::DecodeL1:
    return {kHeadCount,
            kPartialTokenCount,
            kTilesPerHeadDimension,
            kHeadTileRows,
            kSequenceCount,
            input_address(addresses, InputIndex::Input0),
            input_address(addresses, InputIndex::Input1),
            input_address(addresses, InputIndex::Input2),
            input_address(addresses, InputIndex::Input3),
            input_address(addresses, InputIndex::Input4),
            input_address(addresses, InputIndex::Input5),
            addresses.state,
            0,
            0,
            0,
            kOneChunk,
            0,
            kInstanceCount};
  case ReaderCaseKind::ChunkedPartialL1:
    return {kHeadCount,
            kChunkSize,
            kTilesPerHeadDimension,
            kHeadTileRows,
            kSequenceCount,
            input_address(addresses, InputIndex::Input0),
            input_address(addresses, InputIndex::Input1),
            input_address(addresses, InputIndex::Input2),
            input_address(addresses, InputIndex::Input3),
            input_address(addresses, InputIndex::Input4),
            input_address(addresses, InputIndex::Input5),
            addresses.state,
            kPartialTokenCount,
            0,
            0,
            kOneChunk,
            0,
            kInstanceCount};
  case ReaderCaseKind::ChunkedFullL32:
    return {kHeadCount,
            kChunkSize,
            kTilesPerHeadDimension,
            kHeadTileRows,
            kSequenceCount,
            input_address(addresses, InputIndex::Input0),
            input_address(addresses, InputIndex::Input1),
            input_address(addresses, InputIndex::Input2),
            input_address(addresses, InputIndex::Input3),
            input_address(addresses, InputIndex::Input4),
            input_address(addresses, InputIndex::Input5),
            addresses.state,
            kFullChunkTokenCount,
            0,
            0,
            kOneChunk,
            0,
            kInstanceCount};
  }
  return {};
}

std::vector<std::uint32_t> to_vector(
    const std::array<std::uint32_t, kReaderRuntimeArgumentCount> &values) {
  return std::vector<std::uint32_t>(values.begin(), values.end());
}

std::uint32_t input_buffer_tile_count(std::uint32_t token_count) {
  return kSequenceCount * token_count * kHeadTileRows * kTilesPerHeadDimension;
}

ExpectedTile make_state_tile(bool writer, std::uint32_t head,
                             std::uint32_t tile_row,
                             std::uint32_t tile_column) {
  ExpectedTile tile;
  tile.values.reserve(kElementsPerTile);
  tile.compared.assign(kElementsPerTile, true);
  tile.region = ReaderRegion::State;
  tile.head = head;
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

ExpectedTile make_reader_input_tile(const ReaderCase &reader_case,
                                    std::uint32_t tensor, std::uint32_t head,
                                    std::uint32_t dimension_tile) {
  ExpectedTile tile;
  tile.values.reserve(kElementsPerTile);
  tile.compared.reserve(kElementsPerTile);
  tile.region = ReaderRegion::Input;
  tile.head = head;
  const float neutral = tensor == kDecayTensorIndex ? 1.0F : 0.0F;
  for (std::uint32_t row = 0; row < kTileHeight; ++row) {
    for (std::uint32_t column = 0; column < kTileWidth; ++column) {
      const bool token_is_real = row < reader_case.real_token_count;
      if (token_is_real) {
        tile.values.push_back(
            input_tag(tensor, row, head, dimension_tile * kTileWidth + column));
      } else {
        tile.values.push_back(neutral);
      }
      tile.compared.push_back(reader_case.path == Path::Chunked || row == 0);
    }
  }
  return tile;
}

std::vector<ExpectedTile> expected_reader_tiles(const ReaderCase &reader_case) {
  std::vector<ExpectedTile> tiles;
  tiles.reserve(kReaderCaptureTileCount);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    if (reader_case.path == Path::Decode) {
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
            make_reader_input_tile(reader_case, tensor, head, dimension_tile));
      }
    }
    if (reader_case.path == Path::Chunked) {
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

ReaderComparison compare_reader_tiles(const std::vector<ExpectedTile> &expected,
                                      const std::vector<float> &actual) {
  ReaderComparison comparison;
  const std::size_t expected_size = expected.size() * kElementsPerTile;
  if (actual.size() != expected_size) {
    comparison.summary.mismatch_count = expected_size + actual.size() + 1;
    return comparison;
  }
  for (std::size_t tile_index = 0; tile_index < expected.size(); ++tile_index) {
    bool tile_mismatched = false;
    for (std::size_t element_index = 0; element_index < kElementsPerTile;
         ++element_index) {
      if (!expected[tile_index].compared[element_index]) {
        continue;
      }
      const std::size_t global_index =
          tile_index * kElementsPerTile + element_index;
      const float expected_value = expected[tile_index].values[element_index];
      const float actual_value = actual[global_index];
      if (actual_value == expected_value) {
        continue;
      }
      if (comparison.summary.mismatch_count == kNoMismatch) {
        comparison.summary.first_mismatch = global_index;
        comparison.summary.first_expected = expected_value;
        comparison.summary.first_actual = actual_value;
      }
      ++comparison.summary.mismatch_count;
      tile_mismatched = true;
      const std::size_t row = element_index / kTileWidth;
      const std::size_t column = element_index % kTileWidth;
      const std::size_t face = column / kFaceWidth;
      ++comparison.row_mismatches[row];
      ++comparison.face_mismatches[face];
      ++comparison.head_mismatches[expected[tile_index].head];
      if (expected[tile_index].region == ReaderRegion::Input) {
        ++comparison.input_mismatches;
      } else {
        ++comparison.state_mismatches;
      }
    }
    if (tile_mismatched) {
      ++comparison.mismatched_tiles;
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
      output.region = ReaderRegion::Input;
      output.head = head;
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
            kWriterTokenRows + (head * kHeadSize + row) / kHeadCount;
        const std::uint32_t destination_column =
            ((head * kHeadSize + row) % kHeadCount) * kHeadSize + column;
        matrix[static_cast<std::size_t>(destination_row) * kChannelCount +
               destination_column] = writer_state_tag(head, row, column);
      }
    }
  }
  return matrix;
}

std::vector<float> capture_control_matrix() {
  std::vector<float> matrix;
  matrix.reserve(kControlTileCount * kElementsPerTile);
  for (std::uint32_t tile = 0; tile < kControlTileCount; ++tile) {
    for (std::uint32_t row = 0; row < kTileHeight; ++row) {
      for (std::uint32_t column = 0; column < kTileWidth; ++column) {
        matrix.push_back(capture_control_tag(tile, row, column));
      }
    }
  }
  return matrix;
}

std::vector<float> native_input_matrix(std::uint32_t tensor,
                                       std::uint32_t token_count) {
  std::vector<float> matrix;
  matrix.reserve(static_cast<std::size_t>(token_count) * kHeadCount *
                 kHeadSize);
  for (std::uint32_t token = 0; token < token_count; ++token) {
    for (std::uint32_t head = 0; head < kHeadCount; ++head) {
      for (std::uint32_t dimension = 0; dimension < kHeadSize; ++dimension) {
        matrix.push_back(input_tag(tensor, token, head, dimension));
      }
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

Comparison compare_values(const std::vector<float> &expected,
                          const std::vector<float> &actual) {
  Comparison comparison;
  if (actual.size() != expected.size()) {
    comparison.mismatch_count = expected.size() + actual.size() + 1;
    return comparison;
  }
  for (std::size_t index = 0; index < expected.size(); ++index) {
    if (actual[index] == expected[index]) {
      continue;
    }
    if (comparison.mismatch_count == kNoMismatch) {
      comparison.first_mismatch = index;
      comparison.first_expected = expected[index];
      comparison.first_actual = actual[index];
    }
    ++comparison.mismatch_count;
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

bool expect_args_exact(
    const char *fixture,
    const std::array<std::uint32_t, kReaderRuntimeArgumentCount> &expected,
    const std::array<std::uint32_t, kReaderRuntimeArgumentCount> &actual) {
  if (expected == actual) {
    return true;
  }
  std::fprintf(stderr, "reader ABI fixture %s did not match\n", fixture);
  return false;
}

bool expect_args_rejected(
    const char *fixture,
    const std::array<std::uint32_t, kReaderRuntimeArgumentCount> &expected,
    const std::array<std::uint32_t, kReaderRuntimeArgumentCount> &actual) {
  if (expected != actual) {
    return true;
  }
  std::fprintf(stderr, "reader ABI mutation %s was accepted\n", fixture);
  return false;
}

template <std::size_t Size>
std::string histogram_text(const std::array<std::size_t, Size> &histogram) {
  std::ostringstream output;
  for (std::size_t index = 0; index < Size; ++index) {
    if (index != 0) {
      output << ',';
    }
    output << histogram[index];
  }
  return output.str();
}

std::string comparison_text(const Comparison &comparison) {
  std::ostringstream output;
  output << "mismatches=" << comparison.mismatch_count;
  if (comparison.mismatch_count != kNoMismatch) {
    output << " first=" << comparison.first_mismatch
           << " expected=" << comparison.first_expected
           << " actual=" << comparison.first_actual;
  }
  output << (comparison.mismatch_count == kNoMismatch ? " PASS" : " FAIL");
  return output.str();
}

std::string reader_comparison_text(const ReaderComparison &comparison) {
  std::ostringstream output;
  output << comparison_text(comparison.summary)
         << " input=" << comparison.input_mismatches
         << " state=" << comparison.state_mismatches
         << " tiles=" << comparison.mismatched_tiles
         << " rows=" << histogram_text(comparison.row_mismatches)
         << " faces=" << histogram_text(comparison.face_mismatches)
         << " heads=" << histogram_text(comparison.head_mismatches);
  return output.str();
}

std::string capture_manifest_line(std::string_view name,
                                  std::size_t element_count) {
  const std::size_t byte_count = element_count * sizeof(bfloat16);
  std::ostringstream output;
  output << "capture\t" << name << '\t' << name << ".bf16\t" << element_count
         << '\t' << byte_count;
  return output.str();
}

bool run_self_tests(bool print_result) {
  bool passed = true;

  ReaderAddresses fixture_addresses;
  for (std::uint32_t input = 0; input < kInputTensorCount; ++input) {
    fixture_addresses.inputs[input] =
        kFixtureInputAddressBase + input * kFixtureInputAddressStride;
  }
  fixture_addresses.state = kFixtureStateAddress;

  for (const ReaderCase &reader_case : kReaderCases) {
    if (!reader_case_is_valid(reader_case)) {
      std::fprintf(stderr, "reader case invariant failed for %s\n",
                   reader_case.name.data());
      passed = false;
    }
    const auto expected_fixture =
        expected_reader_runtime_fixture(reader_case, fixture_addresses);
    const auto actual_fixture = serialize_reader_runtime_arguments(
        make_reader_runtime_arguments(reader_case, fixture_addresses));
    passed &= expect_args_exact(reader_case.name.data(), expected_fixture,
                                actual_fixture);

    auto changed_length = actual_fixture;
    changed_length[reader_arg_index(ReaderArgIndex::KernelLength)] =
        reader_case.kernel_length == kChunkSize ? kPartialTokenCount
                                                : kChunkSize;
    passed &=
        expect_args_rejected("kernel-length", expected_fixture, changed_length);

    auto changed_real_length = actual_fixture;
    ++changed_real_length[reader_arg_index(ReaderArgIndex::RealLengthOrUnused)];
    passed &= expect_args_rejected("real-length", expected_fixture,
                                   changed_real_length);

    auto changed_chunk_count = actual_fixture;
    ++changed_chunk_count[reader_arg_index(ReaderArgIndex::ChunkCount)];
    passed &= expect_args_rejected("chunk-count", expected_fixture,
                                   changed_chunk_count);

    auto changed_instance_start = actual_fixture;
    ++changed_instance_start[reader_arg_index(ReaderArgIndex::InstanceStart)];
    passed &= expect_args_rejected("instance-start", expected_fixture,
                                   changed_instance_start);

    auto changed_instance_end = actual_fixture;
    --changed_instance_end[reader_arg_index(ReaderArgIndex::InstanceEnd)];
    passed &= expect_args_rejected("instance-end", expected_fixture,
                                   changed_instance_end);

    const auto expected_tiles = expected_reader_tiles(reader_case);
    const auto exact = materialize_reader_tiles(expected_tiles);
    if (expected_tiles.size() != kReaderCaptureTileCount) {
      std::fprintf(stderr,
                   "reader oracle returned an invalid tile count for %s\n",
                   reader_case.name.data());
      passed = false;
    }
    passed &= expect_exact(reader_case.name.data(),
                           compare_reader_tiles(expected_tiles, exact).summary);

    auto transposed = exact;
    const std::size_t state_tile =
        reader_case.path == Path::Decode ? 0 : kInputTilesPerInstance;
    const std::size_t state_offset = state_tile * kElementsPerTile;
    std::swap(transposed[state_offset + 1],
              transposed[state_offset + kTileWidth]);
    const ReaderComparison transpose_comparison =
        compare_reader_tiles(expected_tiles, transposed);
    passed &= expect_rejected("reader-row-column-transpose",
                              transpose_comparison.summary);
    if (transpose_comparison.state_mismatches == kNoMismatch ||
        transpose_comparison.mismatched_tiles == kNoMismatch) {
      std::fprintf(stderr,
                   "reader histogram did not classify state corruption\n");
      passed = false;
    }

    auto permuted = exact;
    for (std::size_t element = 0; element < kElementsPerTile; ++element) {
      std::swap(permuted[element], permuted[kElementsPerTile + element]);
    }
    passed &=
        expect_rejected("reader-tile-permutation",
                        compare_reader_tiles(expected_tiles, permuted).summary);

    auto dropped = exact;
    dropped.resize(dropped.size() - kElementsPerTile);
    passed &= expect_rejected(
        "reader-drop", compare_reader_tiles(expected_tiles, dropped).summary);

    auto duplicated = exact;
    duplicated.insert(duplicated.end(), exact.begin(),
                      exact.begin() + kElementsPerTile);
    passed &= expect_rejected(
        "reader-duplicate",
        compare_reader_tiles(expected_tiles, duplicated).summary);
  }

  ReaderCase invalid_chunk_length = kReaderCases[kChunkedPartialCaseIndex];
  invalid_chunk_length.kernel_length = kPartialTokenCount;
  if (reader_case_is_valid(invalid_chunk_length)) {
    std::fprintf(stderr, "invalid chunk length case was accepted\n");
    passed = false;
  }
  ReaderCase invalid_real_length = kReaderCases[kChunkedPartialCaseIndex];
  invalid_real_length.real_token_count = 0;
  if (reader_case_is_valid(invalid_real_length)) {
    std::fprintf(stderr, "zero real length case was accepted\n");
    passed = false;
  }
  ReaderCase invalid_chunk_count = kReaderCases[kChunkedPartialCaseIndex];
  ++invalid_chunk_count.chunk_count;
  if (reader_case_is_valid(invalid_chunk_count)) {
    std::fprintf(stderr, "invalid chunk count case was accepted\n");
    passed = false;
  }
  if (control_tile_count_is_valid(kMaximumControlTileCount + 1)) {
    std::fprintf(stderr, "oversized control tile count was accepted\n");
    passed = false;
  }

  const ReaderCase &partial_case = kReaderCases[kChunkedPartialCaseIndex];
  const auto partial_fixture =
      expected_reader_runtime_fixture(partial_case, fixture_addresses);
  auto exhausted_vector = partial_fixture;
  exhausted_vector[reader_arg_index(ReaderArgIndex::KernelLength)] =
      kPartialTokenCount;
  passed &= expect_args_rejected("exhausted-L1-Lreal1-chunked-vector",
                                 partial_fixture, exhausted_vector);

  const auto control = capture_control_matrix();
  const auto control_round_trip = untilize_values(
      tilize_values(control, kControlTileCount * kTileHeight, kTileWidth),
      kControlTileCount * kTileHeight, kTileWidth);
  passed &= expect_exact("capture-control-layout",
                         compare_values(control, control_round_trip));

  for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
    const auto input = native_input_matrix(tensor, kFullChunkTokenCount);
    const std::uint32_t input_rows = kFullChunkTokenCount * kHeadCount;
    const auto input_round_trip = untilize_values(
        tilize_values(input, input_rows, kHeadSize), input_rows, kHeadSize);
    passed &= expect_exact("input-upload-layout",
                           compare_values(input, input_round_trip));
    if (input.size() != static_cast<std::size_t>(input_rows) * kHeadSize ||
        input[(kSampleToken * kHeadCount + kSampleHead) * kHeadSize +
              kSampleRow] !=
            input_tag(tensor, kSampleToken, kSampleHead, kSampleRow) ||
        input[(kLastToken * kHeadCount + kLastHead) * kHeadSize +
              kLastDimension] !=
            input_tag(tensor, kLastToken, kLastHead, kLastDimension)) {
      std::fprintf(stderr,
                   "native input source layout mismatch for tensor %u\n",
                   tensor);
      passed = false;
    }
  }

  const auto state_input = flat_state_matrix();
  const std::size_t first_padded_state = kStateColumnCount;
  const auto state_round_trip = untilize_values(
      tilize_values(state_input, kSequenceCountPadded, kStateColumnCount),
      kSequenceCountPadded, kStateColumnCount);
  passed &= expect_exact("state-upload-layout",
                         compare_values(state_input, state_round_trip));
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
      static_cast<std::size_t>(kWriterTokenRows +
                               (kSampleHead * kHeadSize + kSampleRow) /
                                   kHeadCount) *
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
      static_cast<std::size_t>(kWriterTokenRows) * kChannelCount;
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

  if (input_tag(0, 0, 0, 0) == input_tag(1, 0, 0, 0) ||
      reader_state_tag(0, 0, 0) == writer_state_tag(0, 0, 0)) {
    std::fprintf(stderr, "tag domains are not separated\n");
    passed = false;
  }

  const std::string expected_manifest = "capture\tsample\tsample.bf16\t4\t8";
  if (capture_manifest_line("sample", kArtifactFixtureElementCount) !=
      expected_manifest) {
    std::fprintf(stderr, "artifact manifest fixture mismatch\n");
    passed = false;
  }

  if (print_result) {
    std::printf("data-movement oracle self-test: %s\n",
                passed ? "PASS" : "FAIL");
  }
  return passed;
}

class ArtifactSink {
public:
  explicit ArtifactSink(const char *logs_path) {
    if (logs_path == nullptr || logs_path[0] == '\0') {
      return;
    }
    root_ =
        std::filesystem::path(logs_path) / std::string(kArtifactDirectoryName);
    std::error_code error;
    std::filesystem::create_directories(root_, error);
    if (error) {
      return;
    }
    manifest_.open(root_ / std::string(kManifestFilename),
                   std::ios::out | std::ios::trunc);
    if (!manifest_) {
      return;
    }
    manifest_ << "kind\tname\tartifact\telements\tdetail\n";
    manifest_.flush();
    ready_ = static_cast<bool>(manifest_);
  }

  bool ready() const { return ready_; }

  bool write_capture(std::string_view name, const std::vector<bfloat16> &raw) {
    if (!ready_) {
      return false;
    }
    const std::filesystem::path filename =
        std::string(name) + std::string(".bf16");
    std::ofstream output(root_ / filename,
                         std::ios::binary | std::ios::out | std::ios::trunc);
    if (!output) {
      return false;
    }
    const std::size_t byte_count = raw.size() * sizeof(bfloat16);
    output.write(reinterpret_cast<const char *>(raw.data()),
                 static_cast<std::streamsize>(byte_count));
    output.close();
    if (!output) {
      return false;
    }
    manifest_ << capture_manifest_line(name, raw.size()) << '\n';
    manifest_.flush();
    return static_cast<bool>(manifest_);
  }

  bool write_arguments(std::string_view name,
                       const std::vector<std::uint32_t> &arguments) {
    if (!ready_) {
      return false;
    }
    const std::filesystem::path filename =
        std::string(name) + std::string(".args");
    std::ofstream output(root_ / filename, std::ios::out | std::ios::trunc);
    if (!output) {
      return false;
    }
    for (std::size_t index = 0; index < arguments.size(); ++index) {
      output << index << '\t' << arguments[index] << '\n';
    }
    output.close();
    if (!output) {
      return false;
    }
    manifest_ << "args\t" << name << '\t' << filename.string() << '\t'
              << arguments.size() << '\t' << arguments.size() << '\n';
    manifest_.flush();
    return static_cast<bool>(manifest_);
  }

  bool write_summary(std::string_view name, const std::string &summary) {
    if (!ready_) {
      return false;
    }
    manifest_ << "result\t" << name << "\t-\t0\t" << summary << '\n';
    manifest_.flush();
    return static_cast<bool>(manifest_);
  }

private:
  std::filesystem::path root_;
  std::ofstream manifest_;
  bool ready_ = false;
};

bool run_artifact_self_test(const std::filesystem::path &root) {
  ArtifactSink artifacts(root.c_str());
  if (!artifacts.ready()) {
    std::fprintf(stderr, "artifact self-test root was rejected\n");
    return false;
  }

  const std::vector<float> fixture_values(kArtifactFixtureElementCount,
                                          kArtifactFixtureValue);
  const std::vector<bfloat16> fixture = to_bfloat16(fixture_values);
  const std::vector<std::uint32_t> fixture_arguments = {
      kChunkSize, kPartialTokenCount, kOneChunk};
  bool passed = artifacts.write_capture("sample", fixture);
  passed &= artifacts.write_arguments("sample-producer", fixture_arguments);
  passed &= artifacts.write_summary("sample", "mismatches=0 PASS");

  const std::filesystem::path artifact_root =
      root / std::string(kArtifactDirectoryName);
  const std::filesystem::path raw_path = artifact_root / "sample.bf16";
  const std::filesystem::path args_path =
      artifact_root / "sample-producer.args";
  const std::filesystem::path manifest_path =
      artifact_root / std::string(kManifestFilename);
  std::error_code error;
  const std::uintmax_t raw_size = std::filesystem::file_size(raw_path, error);
  passed &= !error;
  passed &= raw_size == kArtifactFixtureElementCount * sizeof(bfloat16);
  passed &= std::filesystem::is_regular_file(args_path);
  passed &= std::filesystem::is_regular_file(manifest_path);

  std::ifstream manifest(manifest_path);
  std::ostringstream manifest_text;
  manifest_text << manifest.rdbuf();
  passed &= static_cast<bool>(manifest);
  passed &= manifest_text.str().find(capture_manifest_line(
                "sample", kArtifactFixtureElementCount)) != std::string::npos;
  passed &= manifest_text.str().find(
                "result\tsample\t-\t0\tmismatches=0 PASS") != std::string::npos;

  std::printf("data-movement artifact self-test: %s\n",
              passed ? "PASS" : "FAIL");
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

WorkloadCapture
run_cb21_copy(const std::shared_ptr<distributed::MeshDevice> &device,
              const std::vector<bfloat16> &source_data) {
  if (source_data.empty() || source_data.size() % kElementsPerTile != 0) {
    throw std::invalid_argument("CB21 control source is not tile aligned");
  }
  const std::uint32_t tile_count =
      static_cast<std::uint32_t>(source_data.size() / kElementsPerTile);
  if (!control_tile_count_is_valid(tile_count)) {
    throw std::invalid_argument("CB21 control exceeds the reviewed tile bound");
  }
  auto &queue = device->mesh_command_queue();
  auto source = make_buffer(device, tile_count);
  auto capture = make_buffer(device, tile_count);
  distributed::EnqueueWriteMeshBuffer(queue, source, source_data, false);

  Program program = CreateProgram();
  make_circular_buffer(program, kReaderOutputCb, kReaderCbCapacityTiles);

  std::vector<std::uint32_t> source_compile_args;
  TensorAccessorArgs(*source).append_to(source_compile_args);
  const auto source_reader = CreateKernel(
      program, std::string(kCaptureSourceReader), kProbeCore,
      DataMovementConfig{.processor = DataMovementProcessor::RISCV_0,
                         .noc = NOC::RISCV_0_default,
                         .compile_args = source_compile_args});

  std::vector<std::uint32_t> capture_compile_args;
  TensorAccessorArgs(*capture).append_to(capture_compile_args);
  const auto capture_writer = CreateKernel(
      program, std::string(kCaptureWriter), kProbeCore,
      DataMovementConfig{.processor = DataMovementProcessor::RISCV_1,
                         .noc = NOC::RISCV_1_default,
                         .compile_args = capture_compile_args});

  WorkloadCapture result;
  result.producer_args = {static_cast<std::uint32_t>(source->address()),
                          tile_count};
  result.consumer_args = {static_cast<std::uint32_t>(capture->address()),
                          tile_count};
  SetRuntimeArgs(program, source_reader, kProbeCore, result.producer_args);
  SetRuntimeArgs(program, capture_writer, kProbeCore, result.consumer_args);

  distributed::MeshWorkload workload;
  workload.add_program(distributed::MeshCoordinateRange(device->shape()),
                       std::move(program));
  distributed::EnqueueMeshWorkload(queue, workload, false);
  distributed::Finish(queue);
  distributed::EnqueueReadMeshBuffer(queue, result.raw, capture, true);
  return result;
}

WorkloadCapture
run_matrix_control(const std::shared_ptr<distributed::MeshDevice> &device,
                   const std::vector<float> &matrix, std::uint32_t rows,
                   std::uint32_t columns) {
  return run_cb21_copy(device,
                       to_bfloat16(tilize_values(matrix, rows, columns)));
}

WorkloadCapture
run_reader_capture(const std::shared_ptr<distributed::MeshDevice> &device,
                   const ReaderCase &reader_case) {
  if (!reader_case_is_valid(reader_case)) {
    throw std::invalid_argument("reader case violates the reviewed ABI");
  }
  auto &queue = device->mesh_command_queue();
  std::array<std::shared_ptr<distributed::MeshBuffer>, kInputTensorCount>
      inputs;
  const std::uint32_t input_tile_count =
      input_buffer_tile_count(reader_case.real_token_count);
  const std::uint32_t input_rows = reader_case.real_token_count * kHeadCount;
  for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
    inputs[tensor] = make_buffer(device, input_tile_count);
    const auto tiled =
        tilize_values(native_input_matrix(tensor, reader_case.real_token_count),
                      input_rows, kHeadSize);
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
      std::string(reader_case.path == Path::Chunked ? kChunkedReader
                                                    : kDecodeReader),
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

  ReaderAddresses addresses;
  for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
    addresses.inputs[tensor] =
        static_cast<std::uint32_t>(inputs[tensor]->address());
  }
  addresses.state = static_cast<std::uint32_t>(state->address());
  const auto serialized = serialize_reader_runtime_arguments(
      make_reader_runtime_arguments(reader_case, addresses));

  WorkloadCapture result;
  result.producer_args = to_vector(serialized);
  result.consumer_args = {static_cast<std::uint32_t>(capture->address()),
                          kReaderCaptureTileCount};
  SetRuntimeArgs(program, reader, kProbeCore, result.producer_args);
  SetRuntimeArgs(program, capture_writer, kProbeCore, result.consumer_args);

  distributed::MeshWorkload workload;
  workload.add_program(distributed::MeshCoordinateRange(device->shape()),
                       std::move(program));
  distributed::EnqueueMeshWorkload(queue, workload, false);
  distributed::Finish(queue);
  distributed::EnqueueReadMeshBuffer(queue, result.raw, capture, true);
  return result;
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

WorkloadCapture
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
      program, std::string(kWriterSourceReader), kProbeCore,
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

  WorkloadCapture result;
  result.producer_args = {static_cast<std::uint32_t>(source->address()),
                          kWriterSourceTileCount};
  const std::uint32_t tokens_per_chunk =
      path == Path::Chunked ? kChunkedTokensPerChunk : kDecodeTokensPerChunk;
  const std::uint32_t group_size =
      path == Path::Chunked ? kChunkedGroupSize : kDecodeGroupSize;
  result.consumer_args = {static_cast<std::uint32_t>(output->address()),
                          0,
                          kInstanceCount,
                          kInstanceCount,
                          kOneChunk,
                          kHeadCount,
                          kTilesPerHeadDimension,
                          kWriterOutputTileColumns,
                          kWriterTokenRows,
                          kPartialTokenCount,
                          tokens_per_chunk,
                          group_size};
  SetRuntimeArgs(program, source_reader, kProbeCore, result.producer_args);
  SetRuntimeArgs(program, writer, kProbeCore, result.consumer_args);

  distributed::MeshWorkload workload;
  workload.add_program(distributed::MeshCoordinateRange(device->shape()),
                       std::move(program));
  distributed::EnqueueMeshWorkload(queue, workload, false);
  distributed::Finish(queue);
  distributed::EnqueueReadMeshBuffer(queue, result.raw, output, true);
  return result;
}

bool record_capture(ArtifactSink &artifacts, std::string_view name,
                    const WorkloadCapture &capture) {
  const std::string producer_name = std::string(name) + "-producer";
  const std::string consumer_name = std::string(name) + "-consumer";
  bool passed = artifacts.write_capture(name, capture.raw);
  passed &= artifacts.write_arguments(producer_name, capture.producer_args);
  passed &= artifacts.write_arguments(consumer_name, capture.consumer_args);
  return passed;
}

void print_control_record(std::string_view name, const Comparison &comparison) {
  std::printf("case=%s phase=control %s\n", std::string(name).c_str(),
              comparison_text(comparison).c_str());
}

void print_reader_record(const ReaderCase &reader_case,
                         const ReaderComparison &comparison) {
  std::printf("case=%s phase=reader-capture %s\n",
              std::string(reader_case.name).c_str(),
              reader_comparison_text(comparison).c_str());
}

void print_writer_record(Path path, const Comparison &comparison) {
  std::printf("case=%s phase=writer-scatter %s\n", path_name(path),
              comparison_text(comparison).c_str());
}

bool run_device_probe() {
  ArtifactSink artifacts(std::getenv("TT_METAL_LOGS_PATH"));
  if (!artifacts.ready()) {
    std::fprintf(stderr, "data-movement artifact root could not be prepared\n");
    return false;
  }

  auto device = distributed::MeshDevice::create_unit_mesh(kLogicalDeviceIndex);
  bool passed = true;

  const auto control_matrix = capture_control_matrix();
  const WorkloadCapture control_capture = run_matrix_control(
      device, control_matrix, kControlTileCount * kTileHeight, kTileWidth);
  bool control_artifacts =
      record_capture(artifacts, "cb21-loopback", control_capture);
  const Comparison control_comparison = compare_values(
      control_matrix,
      untilize_values(to_float(control_capture.raw),
                      kControlTileCount * kTileHeight, kTileWidth));
  const std::string control_summary = comparison_text(control_comparison);
  print_control_record("cb21-loopback", control_comparison);
  control_artifacts &=
      artifacts.write_summary("cb21-loopback", control_summary);
  passed &= control_artifacts;
  passed &= control_comparison.mismatch_count == kNoMismatch;

  for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
    const std::string name = "input-upload-" + std::to_string(tensor);
    const auto input_matrix = native_input_matrix(tensor, kFullChunkTokenCount);
    const std::uint32_t input_rows = kFullChunkTokenCount * kHeadCount;
    const WorkloadCapture input_capture =
        run_matrix_control(device, input_matrix, input_rows, kHeadSize);
    bool input_artifacts = record_capture(artifacts, name, input_capture);
    const Comparison input_comparison = compare_values(
        input_matrix,
        untilize_values(to_float(input_capture.raw), input_rows, kHeadSize));
    const std::string input_summary = comparison_text(input_comparison);
    print_control_record(name, input_comparison);
    input_artifacts &= artifacts.write_summary(name, input_summary);
    passed &= input_artifacts;
    passed &= input_comparison.mismatch_count == kNoMismatch;
  }

  const auto state_matrix = flat_state_matrix();
  const WorkloadCapture state_capture = run_matrix_control(
      device, state_matrix, kSequenceCountPadded, kStateColumnCount);
  bool state_artifacts =
      record_capture(artifacts, "state-upload", state_capture);
  const Comparison state_comparison = compare_values(
      state_matrix, untilize_values(to_float(state_capture.raw),
                                    kSequenceCountPadded, kStateColumnCount));
  const std::string state_summary = comparison_text(state_comparison);
  print_control_record("state-upload", state_comparison);
  state_artifacts &= artifacts.write_summary("state-upload", state_summary);
  passed &= state_artifacts;
  passed &= state_comparison.mismatch_count == kNoMismatch;

  for (const ReaderCase &reader_case : kReaderCases) {
    const WorkloadCapture reader_capture =
        run_reader_capture(device, reader_case);
    bool reader_artifacts =
        record_capture(artifacts, reader_case.name, reader_capture);
    const ReaderComparison comparison =
        compare_reader_tiles(expected_reader_tiles(reader_case),
                             untilize_raw_tiles(reader_capture.raw));
    const std::string summary = reader_comparison_text(comparison);
    print_reader_record(reader_case, comparison);
    reader_artifacts &= artifacts.write_summary(reader_case.name, summary);
    passed &= reader_artifacts;
    passed &= comparison.summary.mismatch_count == kNoMismatch;
  }

  for (const Path path : {Path::Chunked, Path::Decode}) {
    const WorkloadCapture writer_capture = run_writer_scatter(device, path);
    const std::string name = std::string(path_name(path)) + "-writer";
    bool writer_artifacts = record_capture(artifacts, name, writer_capture);
    const Comparison comparison =
        compare_values(expected_writer_matrix(),
                       untilize_values(to_float(writer_capture.raw),
                                       kWriterOutputRows, kChannelCount));
    const std::string summary = comparison_text(comparison);
    print_writer_record(path, comparison);
    writer_artifacts &= artifacts.write_summary(name, summary);
    passed &= writer_artifacts;
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
  std::fprintf(stderr, "usage: %s self-test|artifact-self-test ROOT|probe\n",
               program_name);
}

} // namespace ttwkv7::data_movement

int main(int argc, char **argv) {
  using namespace ttwkv7::data_movement;
  if (argc == kArtifactSelfTestArgumentCount &&
      std::string_view(argv[1]) == kArtifactSelfTestMode) {
    return run_artifact_self_test(argv[kArtifactRootArgumentIndex])
               ? kSuccessStatus
               : kProbeFailureStatus;
  }
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
