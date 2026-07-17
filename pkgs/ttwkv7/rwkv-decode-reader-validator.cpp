#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include <blake3.h>
#include <nlohmann/json.hpp>
#include <tt-metalium/bfloat16.hpp>
#include <tt-metalium/tilize_utils.hpp>

#include "ttwkv7-decode-abi.h"
#include "ttwkv7-host-layout.h"

namespace ttwkv7::rwkv_decode_reader {

using Json = nlohmann::json;

constexpr std::uint32_t kHeadCount = 12;
constexpr std::uint32_t kHeadSize = 64;
constexpr std::uint32_t kPaddedHeadCount = 32;
constexpr std::uint32_t kSequenceCount = 1;
constexpr std::uint32_t kTokenCount = 1;
constexpr std::uint32_t kPaddedSequenceCount = 32;
constexpr std::uint32_t kTilesPerHeadDimension =
    kHeadSize / host_layout::kTileWidth;
constexpr std::uint32_t kStateTilesPerHead =
    kTilesPerHeadDimension * kTilesPerHeadDimension;
constexpr std::uint32_t kChannelCount = kHeadCount * kHeadSize;
constexpr std::uint32_t kChannelTileCount =
    kChannelCount / host_layout::kTileWidth;
constexpr std::uint32_t kInstanceStart = 0;
constexpr std::uint32_t kInstanceEnd = kHeadCount;
constexpr std::uint32_t kMultiTokenControlCount = 7;
constexpr std::uint32_t kInputTensorCount = 6;
constexpr std::uint32_t kStateTensorTag = kInputTensorCount;
constexpr std::uint32_t kFaceWidth = 16;
constexpr std::uint32_t kFaceCount = 2;
constexpr std::uint32_t kCompleteFaceMask =
    (static_cast<std::uint32_t>(1) << kFaceCount) - 1;
constexpr std::uint32_t kElementsPerTile =
    host_layout::kTileWidth * host_layout::kTileHeight;
constexpr std::uint32_t kFaceRowBytes = kFaceWidth * sizeof(bfloat16);
constexpr std::uint32_t kFaceBytes = kFaceWidth * kFaceWidth * sizeof(bfloat16);
constexpr std::uint32_t kDramAlignmentBytes = 64;
constexpr std::uint32_t kStateSourcePageCount =
    kHeadCount * kStateTilesPerHead * host_layout::kTileHeight;
constexpr std::uint32_t kInputPageRowSelectionCount =
    kHeadCount * kInputTensorCount * kTilesPerHeadDimension;
constexpr std::uint32_t kStateFaceReadCount =
    kStateSourcePageCount * kFaceCount;
constexpr std::uint32_t kInputFaceReadCount =
    kInputPageRowSelectionCount * kFaceCount;
constexpr std::uint32_t kFaceReadCount =
    kStateFaceReadCount + kInputFaceReadCount;
constexpr std::uint32_t kPairedRowGatherCount =
    kStateSourcePageCount + kInputPageRowSelectionCount;
constexpr std::size_t kStateElementCount =
    static_cast<std::size_t>(kHeadCount) * kHeadSize * kHeadSize;
constexpr std::size_t kInputElementCount =
    static_cast<std::size_t>(kHeadCount) * kInputTensorCount * kHeadSize;
constexpr std::size_t kInputArtifactCount = kInputTensorCount;
constexpr std::size_t kVectorElementCount =
    static_cast<std::size_t>(kHeadCount) * kHeadSize;
constexpr std::size_t kBf16Bytes = sizeof(bfloat16);
constexpr std::size_t kMatrixRank = 2;
constexpr std::size_t kDigestBytes = BLAKE3_OUT_LEN;
constexpr std::size_t kDigestHexCharacters = kDigestBytes * 2;
constexpr std::size_t kHexCharactersPerByte = 2;
constexpr std::size_t kHexDigitCount = 16;
constexpr std::size_t kBytesPerKibibyte = 1024;
constexpr std::size_t kMaximumFixtureBytes =
    kBytesPerKibibyte * kBytesPerKibibyte;
constexpr std::size_t kExpectedFixtureBytes = 420072;
constexpr std::uint32_t kBitsPerByte = 8;
constexpr std::uint32_t kBitsPerNibble = 4;
constexpr std::uint8_t kNibbleMask = 0x0f;
constexpr std::uint8_t kDecimalDigitCount = 10;
constexpr std::uint32_t kBf16WideningShift = 16;
constexpr std::uint32_t kSchemaVersion = 1;
constexpr std::uint32_t kFixtureSchemaVersion = 1;
constexpr std::uint32_t kLayerIndex = 0;
constexpr std::uint32_t kInputAAddress = 0x1000;
constexpr std::uint32_t kInputWAddress = 0x2000;
constexpr std::uint32_t kInputKAddress = 0x3000;
constexpr std::uint32_t kInputVAddress = 0x4000;
constexpr std::uint32_t kInputRAddress = 0x5000;
constexpr std::uint32_t kInputBAddress = 0x6000;
constexpr std::array<std::uint32_t, kInputArtifactCount> kInputAddresses = {
    kInputAAddress, kInputWAddress, kInputKAddress,
    kInputVAddress, kInputRAddress, kInputBAddress};
constexpr std::uint32_t kStateAddress = 0x7000;
constexpr std::uint32_t kOutputAddress = 0x8000;
constexpr std::uint32_t kReviewedStateSourcePageCount = 1536;
constexpr std::uint32_t kReviewedInputPageRowSelectionCount = 144;
constexpr std::uint32_t kReviewedFaceReadCount = 3360;
constexpr std::uint32_t kReviewedPairedRowGatherCount = 1680;
constexpr std::size_t kReviewedStateElementCount = 49152;
constexpr std::size_t kReviewedInputElementCount = 4608;
constexpr int kExpectedArgumentCount = 2;
constexpr int kSuccessStatus = 0;
constexpr int kValidationFailureStatus = 1;
constexpr int kInvalidArgumentStatus = 2;
constexpr std::string_view kTarget = "rwkv_ttwkv7_decode_reader_abi";
constexpr std::string_view kFixtureTarget = "ttwkv7_logical_wkv_boundary";
constexpr std::string_view kFixtureBlake3 =
    "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
constexpr std::string_view kOrderedArtifactBlake3 =
    "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
constexpr std::string_view kStateUploadBlake3 =
    "a2966fb56eb97345c35c7710f222eac752d7d2f8f84eb0bf2a8e11e85ae466f7";
constexpr std::string_view kDecodeReaderSourceBlake3 =
    "221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca";
constexpr std::string_view kDecodeComputeSourceBlake3 =
    "bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0";
constexpr std::string_view kWriterSourceBlake3 =
    "80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74";
constexpr std::string_view kRuntimeReaderDomain =
    "rwkv-ttwkv7-decode-reader-args-v1";
constexpr std::string_view kRuntimeComputeDomain =
    "rwkv-ttwkv7-decode-compute-args-v1";
constexpr std::string_view kRuntimeWriterDomain =
    "rwkv-ttwkv7-decode-writer-args-v1";
constexpr std::string_view kTraceDomain = "rwkv-ttwkv7-decode-reader-trace-v1";
constexpr std::string_view kStatePayloadDomain =
    "rwkv-ttwkv7-decode-reader-state-v1";
constexpr std::string_view kInputPayloadDomain =
    "rwkv-ttwkv7-decode-reader-input-v1";
constexpr std::string_view kCombinedDomain =
    "rwkv-ttwkv7-decode-reader-evidence-v1";
constexpr std::array<std::string_view, kInputArtifactCount> kInputNames = {
    "a", "w", "k", "v", "r", "b"};
constexpr std::array<std::string_view, kInputArtifactCount>
    kExpectedInputUploadBlake3 = {
        "12038a499897e2a403b179f31a54e7201ffdf6f80402c91d24e0b4c86e5ed849",
        "3e00c954d55ad0f5ab0f9f8b869d81dcb19c5bc572e9637ef6836fc76f8264cc",
        "8ef11709d3f136a17ca7f5a3cf2fb91b52424eeda51d28797be429a12e5f8fa7",
        "e9bea640d3c09a80143dc04be45e77935e7639e1e0f064c0009b8cbfdaba154c",
        "9e64a0be9c6b753dae7ab5300f2fff33a660ef025be6e5893f13f56eaceec534",
        "c7a95d4671b51545417c5bcb930321325d1bfe431746879971bd2335500b6858",
};
constexpr std::array<std::string_view, 8> kNonClaims = {
    "No BRISC instruction or production reader execution is established.",
    "No NoC transfer or circular-buffer initialization behavior is "
    "established.",
    "No unwritten decode input-tile row is assigned a value.",
    "No ttWKV7 compute or writer-kernel execution is established.",
    "No Metalium device initialization or P150 correctness is established.",
    "No repaired-reader completion is established.",
    "No full-layer, full-model, generation, or serving parity is established.",
    "No throughput or latency claim is established.",
};

static_assert(sizeof(bfloat16) == kBf16Bytes);
static_assert(kFaceCount * kFaceWidth == host_layout::kTileWidth);
static_assert(kStateSourcePageCount == kReviewedStateSourcePageCount);
static_assert(kInputPageRowSelectionCount ==
              kReviewedInputPageRowSelectionCount);
static_assert(kFaceReadCount == kReviewedFaceReadCount);
static_assert(kPairedRowGatherCount == kReviewedPairedRowGatherCount);
static_assert(kStateElementCount == kReviewedStateElementCount);
static_assert(kInputElementCount == kReviewedInputElementCount);

struct Shape {
  std::uint32_t head_size;
  std::uint32_t head_count;
  std::uint32_t padded_head_count;
  std::uint32_t tiles_per_head_dimension;
  std::uint32_t head_tile_rows;
  std::uint32_t channel_count;
};

constexpr Shape kShape{
    .head_size = kHeadSize,
    .head_count = kHeadCount,
    .padded_head_count = kPaddedHeadCount,
    .tiles_per_head_dimension = kTilesPerHeadDimension,
    .head_tile_rows = kPaddedHeadCount / host_layout::kTileHeight,
    .channel_count = kChannelCount,
};

struct Artifact {
  std::string name;
  std::vector<std::uint16_t> bits;
  std::vector<float> values;
};

struct Fixture {
  std::array<Artifact, kInputArtifactCount> inputs;
  Artifact pre_state;
};

struct ReaderFormula {
  std::uint32_t state_head_stride_pages;
  std::uint32_t input_head_row_bias;
  bool swap_source_faces;
  bool transpose_state_destination;
};

constexpr ReaderFormula kProductionFormula{
    .state_head_stride_pages = kStateTilesPerHead * host_layout::kTileHeight,
    .input_head_row_bias = 0,
    .swap_source_faces = false,
    .transpose_state_destination = false,
};

enum class ReaderRegion : std::uint32_t {
  State,
  Input,
};

struct FaceRead {
  ReaderRegion region;
  std::uint32_t tensor;
  std::uint32_t head;
  std::uint32_t source_page;
  std::uint32_t source_row;
  std::uint32_t source_face;
  std::uint32_t source_offset;
  std::uint32_t aligned_source_offset;
  std::uint32_t source_remainder;
  std::uint32_t destination_tile;
  std::uint32_t destination_row;
  std::uint32_t destination_face;
  std::uint32_t destination_offset;
};

struct ReaderPayload {
  std::vector<std::uint16_t> state;
  std::vector<std::uint16_t> inputs;
  std::vector<FaceRead> trace;
};

struct ValidationResult {
  decode_abi::DecodeRuntimeArguments runtime_arguments;
  std::array<std::string, kInputArtifactCount> input_upload_blake3;
  std::string state_upload_blake3;
  std::string reader_arguments_blake3;
  std::string compute_arguments_blake3;
  std::string writer_arguments_blake3;
  std::string source_trace_blake3;
  std::string state_payload_blake3;
  std::string input_payload_blake3;
  std::string combined_blake3;
};

std::string digest_hex(const std::array<std::uint8_t, kDigestBytes> &digest) {
  constexpr std::array<char, kHexDigitCount> kHexDigits = {
      '0', '1', '2', '3', '4', '5', '6', '7',
      '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
  std::string output;
  output.reserve(kDigestHexCharacters);
  for (const std::uint8_t byte : digest) {
    output.push_back(kHexDigits[byte >> kBitsPerNibble]);
    output.push_back(kHexDigits[byte & kNibbleMask]);
  }
  return output;
}

std::string finalize_blake3(blake3_hasher &hasher) {
  std::array<std::uint8_t, kDigestBytes> digest{};
  blake3_hasher_finalize(&hasher, digest.data(), digest.size());
  return digest_hex(digest);
}

std::string blake3_hex(const std::uint8_t *data, std::size_t size) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, data, size);
  return finalize_blake3(hasher);
}

std::string blake3_hex(std::string_view text) {
  return blake3_hex(reinterpret_cast<const std::uint8_t *>(text.data()),
                    text.size());
}

void update_u32(blake3_hasher &hasher, std::uint32_t value) {
  std::array<std::uint8_t, sizeof(value)> bytes{};
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    bytes[index] = static_cast<std::uint8_t>(value >> (index * kBitsPerByte));
  }
  blake3_hasher_update(&hasher, bytes.data(), bytes.size());
}

void update_u64(blake3_hasher &hasher, std::uint64_t value) {
  std::array<std::uint8_t, sizeof(value)> bytes{};
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    bytes[index] = static_cast<std::uint8_t>(value >> (index * kBitsPerByte));
  }
  blake3_hasher_update(&hasher, bytes.data(), bytes.size());
}

void update_text(blake3_hasher &hasher, std::string_view text) {
  update_u64(hasher, text.size());
  blake3_hasher_update(&hasher, text.data(), text.size());
}

std::vector<std::uint8_t>
bits_to_bytes(const std::vector<std::uint16_t> &bits) {
  std::vector<std::uint8_t> bytes;
  bytes.reserve(bits.size() * kBf16Bytes);
  for (const std::uint16_t value : bits) {
    bytes.push_back(static_cast<std::uint8_t>(value));
    bytes.push_back(static_cast<std::uint8_t>(value >> kBitsPerByte));
  }
  return bytes;
}

std::string payload_blake3(std::string_view domain,
                           const std::vector<std::uint16_t> &bits) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, domain.data(), domain.size());
  const std::vector<std::uint8_t> bytes = bits_to_bytes(bits);
  update_u64(hasher, bits.size());
  blake3_hasher_update(&hasher, bytes.data(), bytes.size());
  return finalize_blake3(hasher);
}

template <std::size_t Size>
std::string argument_blake3(std::string_view domain,
                            const std::array<std::uint32_t, Size> &arguments) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, domain.data(), domain.size());
  update_u64(hasher, arguments.size());
  for (const std::uint32_t argument : arguments) {
    update_u32(hasher, argument);
  }
  return finalize_blake3(hasher);
}

std::optional<std::uint8_t> lowercase_hex_value(char character) {
  if (character >= '0' && character <= '9') {
    return static_cast<std::uint8_t>(character - '0');
  }
  if (character >= 'a' && character <= 'f') {
    return static_cast<std::uint8_t>(character - 'a' + kDecimalDigitCount);
  }
  return std::nullopt;
}

std::vector<std::uint8_t> decode_lowercase_hex(std::string_view text,
                                               std::string_view name) {
  if (text.empty() || text.size() % kHexCharactersPerByte != 0) {
    throw std::runtime_error(std::string(name) +
                             " has invalid hexadecimal bytes");
  }
  std::vector<std::uint8_t> bytes;
  bytes.reserve(text.size() / kHexCharactersPerByte);
  for (std::size_t index = 0; index < text.size();
       index += kHexCharactersPerByte) {
    const auto high = lowercase_hex_value(text[index]);
    const auto low = lowercase_hex_value(text[index + 1]);
    if (!high || !low) {
      throw std::runtime_error(std::string(name) +
                               " bytes must be lowercase hexadecimal");
    }
    bytes.push_back(
        static_cast<std::uint8_t>((*high << kBitsPerNibble) | *low));
  }
  return bytes;
}

float decode_bf16(std::uint16_t bits) {
  return std::bit_cast<float>(static_cast<std::uint32_t>(bits)
                              << kBf16WideningShift);
}

std::uint16_t encode_bf16(float value) {
  return std::bit_cast<std::uint16_t>(bfloat16(value));
}

Artifact parse_artifact(const Json &value, std::string_view expected_name,
                        const std::vector<std::uint32_t> &expected_shape) {
  const std::string name = value.at("name").get<std::string>();
  if (name != expected_name || value.at("logical_shape") != expected_shape) {
    throw std::runtime_error(std::string(expected_name) +
                             " artifact authority mismatch");
  }
  std::size_t element_count = 1;
  for (const std::uint32_t dimension : expected_shape) {
    element_count *= dimension;
  }
  if (value.at("element_count").get<std::size_t>() != element_count ||
      value.at("byte_count").get<std::size_t>() != element_count * kBf16Bytes) {
    throw std::runtime_error(name + " artifact count mismatch");
  }
  const std::vector<std::uint8_t> bytes =
      decode_lowercase_hex(value.at("bytes_hex").get<std::string>(), name);
  if (bytes.size() != element_count * kBf16Bytes ||
      blake3_hex(bytes.data(), bytes.size()) !=
          value.at("blake3").get<std::string>()) {
    throw std::runtime_error(name + " artifact BLAKE3 mismatch");
  }
  Artifact artifact{
      .name = name,
      .bits = {},
      .values = {},
  };
  artifact.bits.reserve(element_count);
  artifact.values.reserve(element_count);
  for (std::size_t index = 0; index < bytes.size(); index += kBf16Bytes) {
    const std::uint16_t bits =
        static_cast<std::uint16_t>(bytes[index]) |
        (static_cast<std::uint16_t>(bytes[index + 1]) << kBitsPerByte);
    const float value_decoded = decode_bf16(bits);
    if (!std::isfinite(value_decoded) || encode_bf16(value_decoded) != bits) {
      throw std::runtime_error(name + " artifact has invalid BF16 bits");
    }
    artifact.bits.push_back(bits);
    artifact.values.push_back(value_decoded);
  }
  return artifact;
}

Fixture parse_fixture(std::string_view file_bytes) {
  if (file_bytes.size() != kExpectedFixtureBytes ||
      blake3_hex(file_bytes) != kFixtureBlake3) {
    throw std::runtime_error("whole fixture authority mismatch");
  }
  const Json root = Json::parse(file_bytes.begin(), file_bytes.end());
  if (root.at("schema_version").get<std::uint32_t>() != kFixtureSchemaVersion ||
      root.at("layer_index").get<std::uint32_t>() != kLayerIndex ||
      root.at("target").get<std::string>() != kFixtureTarget ||
      root.at("ordered_artifact_blake3").get<std::string>() !=
          kOrderedArtifactBlake3 ||
      root.at("input_order") != kInputNames) {
    throw std::runtime_error("fixture metadata authority mismatch");
  }
  const Json &input_artifacts = root.at("input_artifacts");
  if (!input_artifacts.is_array() ||
      input_artifacts.size() != kInputArtifactCount) {
    throw std::runtime_error("fixture input artifact count mismatch");
  }
  const std::vector<std::uint32_t> vector_shape = {kHeadCount, kHeadSize};
  const std::vector<std::uint32_t> state_shape = {kHeadCount, kHeadSize,
                                                  kHeadSize};
  Fixture fixture;
  for (std::size_t index = 0; index < fixture.inputs.size(); ++index) {
    fixture.inputs[index] = parse_artifact(input_artifacts[index],
                                           kInputNames[index], vector_shape);
  }
  fixture.pre_state =
      parse_artifact(root.at("pre_state_artifact"), "pre_state", state_shape);
  return fixture;
}

std::string read_fixture_file(const std::filesystem::path &path) {
  std::error_code error;
  if (!std::filesystem::is_regular_file(path, error) || error) {
    throw std::runtime_error("fixture path must be a readable regular file");
  }
  const std::uintmax_t size = std::filesystem::file_size(path, error);
  if (error || size == 0 || size > kMaximumFixtureBytes) {
    throw std::runtime_error("fixture size is outside the reviewed bound");
  }
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    throw std::runtime_error("fixture file could not be opened");
  }
  std::ostringstream bytes;
  bytes << input.rdbuf();
  if (!input.good() && !input.eof()) {
    throw std::runtime_error("fixture file could not be read completely");
  }
  return bytes.str();
}

std::vector<float> tilize_values(const std::vector<float> &values,
                                 std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(values),
                        std::array<std::uint32_t, kMatrixRank>{rows, columns},
                        TensorLayoutType::LIN_ROW_MAJOR,
                        TensorLayoutType::TILED_NFACES);
}

std::optional<std::vector<std::uint16_t>>
exact_bits(const std::vector<float> &values) {
  std::vector<std::uint16_t> bits;
  bits.reserve(values.size());
  for (const float value : values) {
    if (!std::isfinite(value)) {
      return std::nullopt;
    }
    const std::uint16_t encoded = encode_bf16(value);
    if (decode_bf16(encoded) != value) {
      return std::nullopt;
    }
    bits.push_back(encoded);
  }
  return bits;
}

std::size_t nfaces_index(std::uint32_t row, std::uint32_t column) {
  const std::uint32_t face_row = row / kFaceWidth;
  const std::uint32_t face_column = column / kFaceWidth;
  const std::uint32_t row_in_face = row % kFaceWidth;
  const std::uint32_t column_in_face = column % kFaceWidth;
  return static_cast<std::size_t>(face_row * kFaceCount + face_column) *
             kFaceWidth * kFaceWidth +
         row_in_face * kFaceWidth + column_in_face;
}

std::uint32_t face_offset(std::uint32_t row, std::uint32_t face) {
  return ((row / kFaceWidth) * kFaceCount + face) * kFaceBytes +
         (row % kFaceWidth) * kFaceRowBytes;
}

std::optional<ReaderPayload> emulate_reader(
    const std::array<std::vector<std::uint16_t>, kInputArtifactCount> &inputs,
    const std::vector<std::uint16_t> &state, const ReaderFormula &formula) {
  const std::size_t expected_input_storage =
      static_cast<std::size_t>(kPaddedHeadCount) * kHeadSize;
  const std::size_t expected_state_storage =
      static_cast<std::size_t>(kPaddedSequenceCount) * kChannelCount *
      kHeadSize;
  for (const auto &input : inputs) {
    if (input.size() != expected_input_storage) {
      return std::nullopt;
    }
  }
  if (state.size() != expected_state_storage) {
    return std::nullopt;
  }

  ReaderPayload payload{
      .state = std::vector<std::uint16_t>(kStateElementCount),
      .inputs = std::vector<std::uint16_t>(kInputElementCount),
      .trace = {},
  };
  std::vector<bool> state_written(kStateElementCount, false);
  std::vector<bool> inputs_written(kInputElementCount, false);
  payload.trace.reserve(kFaceReadCount);

  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t tile_row = 0; tile_row < kTilesPerHeadDimension;
         ++tile_row) {
      for (std::uint32_t tile_column = 0; tile_column < kTilesPerHeadDimension;
           ++tile_column) {
        const std::uint32_t destination_tile =
            head * kStateTilesPerHead + tile_row * kTilesPerHeadDimension +
            tile_column;
        for (std::uint32_t row = 0; row < host_layout::kTileHeight; ++row) {
          const std::uint32_t source_page =
              head * formula.state_head_stride_pages +
              (tile_row * host_layout::kTileHeight + row) *
                  kTilesPerHeadDimension +
              tile_column;
          for (std::uint32_t destination_face = 0;
               destination_face < kFaceCount; ++destination_face) {
            const std::uint32_t source_face =
                formula.swap_source_faces ? kFaceCount - destination_face - 1
                                          : destination_face;
            const std::uint32_t source_offset = face_offset(0, source_face);
            const std::uint32_t destination_offset =
                face_offset(row, destination_face);
            payload.trace.push_back(FaceRead{
                .region = ReaderRegion::State,
                .tensor = kStateTensorTag,
                .head = head,
                .source_page = source_page,
                .source_row = 0,
                .source_face = source_face,
                .source_offset = source_offset,
                .aligned_source_offset =
                    source_offset - source_offset % kDramAlignmentBytes,
                .source_remainder = source_offset % kDramAlignmentBytes,
                .destination_tile = destination_tile,
                .destination_row = row,
                .destination_face = destination_face,
                .destination_offset = destination_offset,
            });
            for (std::uint32_t element = 0; element < kFaceWidth; ++element) {
              const std::uint32_t source_column =
                  source_face * kFaceWidth + element;
              const std::size_t source_index =
                  static_cast<std::size_t>(source_page) * kElementsPerTile +
                  nfaces_index(0, source_column);
              const std::uint32_t logical_column =
                  tile_column * host_layout::kTileWidth +
                  destination_face * kFaceWidth + element;
              const std::uint32_t logical_row =
                  tile_row * host_layout::kTileHeight + row;
              const std::uint32_t destination_row =
                  formula.transpose_state_destination ? logical_column
                                                      : logical_row;
              const std::uint32_t destination_column =
                  formula.transpose_state_destination ? logical_row
                                                      : logical_column;
              const std::uint32_t transposed_tile_row =
                  destination_row / host_layout::kTileHeight;
              const std::uint32_t transposed_tile_column =
                  destination_column / host_layout::kTileWidth;
              const std::uint32_t transposed_tile =
                  head * kStateTilesPerHead +
                  transposed_tile_row * kTilesPerHeadDimension +
                  transposed_tile_column;
              const std::size_t destination_index =
                  static_cast<std::size_t>(transposed_tile) * kElementsPerTile +
                  nfaces_index(destination_row % host_layout::kTileHeight,
                               destination_column % host_layout::kTileWidth);
              if (source_index >= state.size() ||
                  destination_index >= payload.state.size() ||
                  state_written[destination_index]) {
                return std::nullopt;
              }
              payload.state[destination_index] = state[source_index];
              state_written[destination_index] = true;
            }
          }
        }
      }
    }

    const std::uint32_t source_head_row = head + formula.input_head_row_bias;
    if (source_head_row >= kPaddedHeadCount) {
      return std::nullopt;
    }
    const std::uint32_t head_tile_row =
        source_head_row / host_layout::kTileHeight;
    const std::uint32_t row_in_tile =
        source_head_row % host_layout::kTileHeight;
    for (std::uint32_t tensor = 0; tensor < kInputTensorCount; ++tensor) {
      for (std::uint32_t column_tile = 0; column_tile < kTilesPerHeadDimension;
           ++column_tile) {
        const std::uint32_t source_page =
            head_tile_row * kTilesPerHeadDimension + column_tile;
        const std::uint32_t destination_tile =
            (head * kInputTensorCount + tensor) * kTilesPerHeadDimension +
            column_tile;
        for (std::uint32_t destination_face = 0; destination_face < kFaceCount;
             ++destination_face) {
          const std::uint32_t source_face =
              formula.swap_source_faces ? kFaceCount - destination_face - 1
                                        : destination_face;
          const std::uint32_t source_offset =
              face_offset(row_in_tile, source_face);
          const std::uint32_t destination_offset =
              face_offset(0, destination_face);
          payload.trace.push_back(FaceRead{
              .region = ReaderRegion::Input,
              .tensor = tensor,
              .head = head,
              .source_page = source_page,
              .source_row = row_in_tile,
              .source_face = source_face,
              .source_offset = source_offset,
              .aligned_source_offset =
                  source_offset - source_offset % kDramAlignmentBytes,
              .source_remainder = source_offset % kDramAlignmentBytes,
              .destination_tile = destination_tile,
              .destination_row = 0,
              .destination_face = destination_face,
              .destination_offset = destination_offset,
          });
          for (std::uint32_t element = 0; element < kFaceWidth; ++element) {
            const std::uint32_t source_column =
                source_face * kFaceWidth + element;
            const std::size_t source_index =
                static_cast<std::size_t>(source_page) * kElementsPerTile +
                nfaces_index(row_in_tile, source_column);
            const std::uint32_t dimension =
                column_tile * host_layout::kTileWidth +
                destination_face * kFaceWidth + element;
            const std::size_t destination_index =
                (static_cast<std::size_t>(head) * kInputTensorCount + tensor) *
                    kHeadSize +
                dimension;
            if (source_index >= inputs[tensor].size() ||
                destination_index >= payload.inputs.size() ||
                inputs_written[destination_index]) {
              return std::nullopt;
            }
            payload.inputs[destination_index] = inputs[tensor][source_index];
            inputs_written[destination_index] = true;
          }
        }
      }
    }
  }

  for (const bool written : state_written) {
    if (!written) {
      return std::nullopt;
    }
  }
  for (const bool written : inputs_written) {
    if (!written) {
      return std::nullopt;
    }
  }
  if (payload.trace.size() != kFaceReadCount) {
    return std::nullopt;
  }
  return payload;
}

std::vector<std::uint16_t> independent_state_oracle(const Artifact &state) {
  std::vector<std::uint16_t> expected;
  expected.reserve(kStateElementCount);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t tile_row = 0; tile_row < kTilesPerHeadDimension;
         ++tile_row) {
      for (std::uint32_t tile_column = 0; tile_column < kTilesPerHeadDimension;
           ++tile_column) {
        for (std::uint32_t face_row = 0; face_row < kFaceCount; ++face_row) {
          for (std::uint32_t face_column = 0; face_column < kFaceCount;
               ++face_column) {
            for (std::uint32_t row = 0; row < kFaceWidth; ++row) {
              for (std::uint32_t column = 0; column < kFaceWidth; ++column) {
                const std::uint32_t logical_row =
                    tile_row * host_layout::kTileHeight +
                    face_row * kFaceWidth + row;
                const std::uint32_t logical_column =
                    tile_column * host_layout::kTileWidth +
                    face_column * kFaceWidth + column;
                const std::size_t logical_index =
                    (static_cast<std::size_t>(head) * kHeadSize + logical_row) *
                        kHeadSize +
                    logical_column;
                expected.push_back(state.bits[logical_index]);
              }
            }
          }
        }
      }
    }
  }
  return expected;
}

std::vector<std::uint16_t> independent_input_oracle(const Fixture &fixture) {
  std::vector<std::uint16_t> expected;
  expected.reserve(kInputElementCount);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::size_t tensor = 0; tensor < fixture.inputs.size(); ++tensor) {
      const Artifact &input = fixture.inputs[tensor];
      const std::size_t offset = static_cast<std::size_t>(head) * kHeadSize;
      expected.insert(expected.end(), input.bits.begin() + offset,
                      input.bits.begin() + offset + kHeadSize);
    }
  }
  return expected;
}

bool trace_coverage_is_exact(const std::vector<FaceRead> &trace) {
  if (trace.size() != kFaceReadCount) {
    return false;
  }
  std::vector<std::uint32_t> state_page_faces(kStateSourcePageCount, 0);
  std::vector<std::uint32_t> input_selection_faces(kInputPageRowSelectionCount,
                                                   0);
  for (const FaceRead &record : trace) {
    if (record.source_offset !=
            record.aligned_source_offset + record.source_remainder ||
        record.source_remainder >= kDramAlignmentBytes ||
        record.source_face >= kFaceCount ||
        record.destination_face >= kFaceCount ||
        record.source_face != record.destination_face ||
        record.source_offset !=
            face_offset(record.source_row, record.source_face) ||
        record.destination_offset !=
            face_offset(record.destination_row, record.destination_face)) {
      return false;
    }
    const std::uint32_t face_bit = static_cast<std::uint32_t>(1)
                                   << record.source_face;
    if (record.region == ReaderRegion::State) {
      if (record.source_page >= state_page_faces.size() ||
          record.tensor != kStateTensorTag || record.source_row != 0 ||
          (state_page_faces[record.source_page] & face_bit) != 0) {
        return false;
      }
      state_page_faces[record.source_page] |= face_bit;
    } else if (record.region == ReaderRegion::Input) {
      if (record.tensor >= kInputTensorCount || record.head >= kHeadCount ||
          record.source_row != record.head) {
        return false;
      }
      const std::size_t selection =
          (static_cast<std::size_t>(record.head) * kInputTensorCount +
           record.tensor) *
              kTilesPerHeadDimension +
          record.source_page;
      if (selection >= input_selection_faces.size() ||
          (input_selection_faces[selection] & face_bit) != 0) {
        return false;
      }
      input_selection_faces[selection] |= face_bit;
    } else {
      return false;
    }
  }
  for (const std::uint32_t face_mask : state_page_faces) {
    if (face_mask != kCompleteFaceMask) {
      return false;
    }
  }
  for (const std::uint32_t face_mask : input_selection_faces) {
    if (face_mask != kCompleteFaceMask) {
      return false;
    }
  }
  return true;
}

std::string trace_blake3(const std::vector<FaceRead> &trace) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, kTraceDomain.data(), kTraceDomain.size());
  update_u64(hasher, trace.size());
  for (const FaceRead &record : trace) {
    update_u32(hasher, static_cast<std::uint32_t>(record.region));
    update_u32(hasher, record.tensor);
    update_u32(hasher, record.head);
    update_u32(hasher, record.source_page);
    update_u32(hasher, record.source_row);
    update_u32(hasher, record.source_face);
    update_u32(hasher, record.source_offset);
    update_u32(hasher, record.aligned_source_offset);
    update_u32(hasher, record.source_remainder);
    update_u32(hasher, record.destination_tile);
    update_u32(hasher, record.destination_row);
    update_u32(hasher, record.destination_face);
    update_u32(hasher, record.destination_offset);
  }
  return finalize_blake3(hasher);
}

decode_abi::DecodeAddresses fixture_addresses() {
  decode_abi::DecodeAddresses addresses{};
  addresses.inputs = kInputAddresses;
  addresses.state = kStateAddress;
  addresses.output = kOutputAddress;
  return addresses;
}

decode_abi::DecodeConfig fixture_config() {
  return decode_abi::DecodeConfig{
      .head_count = kHeadCount,
      .tiles_per_head_dimension = kTilesPerHeadDimension,
      .head_tile_rows = kShape.head_tile_rows,
      .sequence_count = kSequenceCount,
      .token_count = kTokenCount,
      .channel_tile_count = kChannelTileCount,
  };
}

bool abi_negative_controls_pass() {
  const decode_abi::DecodeConfig valid_config = fixture_config();
  const decode_abi::DecodeAddresses valid_addresses = fixture_addresses();
  const auto full = decode_abi::make_decode_runtime_arguments(
      valid_config, valid_addresses, kInstanceStart, kInstanceEnd);
  const auto first = decode_abi::make_decode_runtime_arguments(
      valid_config, valid_addresses, kInstanceStart, kInstanceStart + 1);
  const auto final = decode_abi::make_decode_runtime_arguments(
      valid_config, valid_addresses, kInstanceEnd - 1, kInstanceEnd);
  decode_abi::DecodeConfig multi_token_config = valid_config;
  multi_token_config.token_count = kMultiTokenControlCount;
  const auto multi_token = decode_abi::make_decode_runtime_arguments(
      multi_token_config, valid_addresses, kInstanceStart, kInstanceEnd);
  if (!full || !first || !final || !multi_token ||
      multi_token->reader[decode_abi::index(
          decode_abi::ReaderArgument::TokenCount)] != kMultiTokenControlCount ||
      multi_token->reader[decode_abi::index(
          decode_abi::ReaderArgument::ChunkCount)] !=
          decode_abi::kDecodeReaderChunkCount ||
      multi_token->compute[decode_abi::index(
          decode_abi::ComputeArgument::ChunkCount)] !=
          decode_abi::kDecodeReaderChunkCount ||
      multi_token->writer[decode_abi::index(
          decode_abi::WriterArgument::ChunkCount)] != kMultiTokenControlCount) {
    return false;
  }

  decode_abi::DecodeConfig changed = valid_config;
  changed.head_count = 0;
  if (decode_abi::make_decode_runtime_arguments(changed, valid_addresses,
                                                kInstanceStart, kInstanceEnd)) {
    return false;
  }
  changed = valid_config;
  ++changed.head_tile_rows;
  if (decode_abi::make_decode_runtime_arguments(changed, valid_addresses,
                                                kInstanceStart, kInstanceEnd)) {
    return false;
  }
  changed = valid_config;
  ++changed.channel_tile_count;
  if (decode_abi::make_decode_runtime_arguments(changed, valid_addresses,
                                                kInstanceStart, kInstanceEnd)) {
    return false;
  }
  changed = valid_config;
  changed.token_count = 0;
  if (decode_abi::make_decode_runtime_arguments(changed, valid_addresses,
                                                kInstanceStart, kInstanceEnd)) {
    return false;
  }
  changed = valid_config;
  changed.token_count = decode_abi::kMaximumTokenCount + 1;
  if (decode_abi::make_decode_runtime_arguments(changed, valid_addresses,
                                                kInstanceStart, kInstanceEnd)) {
    return false;
  }
  decode_abi::DecodeAddresses zero_address = valid_addresses;
  zero_address.inputs.front() = 0;
  return !decode_abi::make_decode_runtime_arguments(
             valid_config, zero_address, kInstanceStart, kInstanceEnd) &&
         !decode_abi::make_decode_runtime_arguments(
             valid_config, valid_addresses, kInstanceStart, kInstanceStart) &&
         !decode_abi::make_decode_runtime_arguments(
             valid_config, valid_addresses, kInstanceEnd, kInstanceStart) &&
         !decode_abi::make_decode_runtime_arguments(
             valid_config, valid_addresses, kInstanceStart, kInstanceEnd + 1);
}

bool exact_runtime_vectors(
    const decode_abi::DecodeRuntimeArguments &arguments) {
  const std::array<std::uint32_t, decode_abi::kReaderArgumentCount>
      expected_reader = {kHeadCount,
                         kTokenCount,
                         kTilesPerHeadDimension,
                         kShape.head_tile_rows,
                         kSequenceCount,
                         kInputAAddress,
                         kInputWAddress,
                         kInputKAddress,
                         kInputVAddress,
                         kInputRAddress,
                         kInputBAddress,
                         kStateAddress,
                         kTokenCount,
                         0,
                         0,
                         kTokenCount,
                         kInstanceStart,
                         kInstanceEnd};
  const std::array<std::uint32_t, decode_abi::kComputeArgumentCount>
      expected_compute = {kTilesPerHeadDimension,
                          kHeadCount,
                          kTokenCount,
                          kShape.head_tile_rows,
                          kTokenCount,
                          kInstanceStart,
                          kInstanceEnd,
                          decode_abi::kDecodeInstancePack};
  const std::array<std::uint32_t, decode_abi::kWriterArgumentCount>
      expected_writer = {kOutputAddress,
                         kInstanceStart,
                         kInstanceEnd,
                         kHeadCount,
                         kTokenCount,
                         kHeadCount,
                         kTilesPerHeadDimension,
                         kChannelTileCount,
                         kTokenCount,
                         kTokenCount,
                         decode_abi::kDecodeTokensPerChunk,
                         decode_abi::kDecodeInstancesPerGroup};
  return arguments.reader == expected_reader &&
         arguments.compute == expected_compute &&
         arguments.writer == expected_writer;
}

bool gather_negative_controls_pass(
    const std::array<std::vector<std::uint16_t>, kInputArtifactCount> &inputs,
    const std::vector<std::uint16_t> &state,
    const std::vector<std::uint16_t> &expected_state,
    const std::vector<std::uint16_t> &expected_inputs) {
  ReaderFormula changed_stride = kProductionFormula;
  ++changed_stride.state_head_stride_pages;
  const auto wrong_stride = emulate_reader(inputs, state, changed_stride);
  if (wrong_stride && wrong_stride->state == expected_state) {
    return false;
  }

  ReaderFormula changed_head_row = kProductionFormula;
  ++changed_head_row.input_head_row_bias;
  const auto wrong_head_row = emulate_reader(inputs, state, changed_head_row);
  if (!wrong_head_row || wrong_head_row->inputs == expected_inputs) {
    return false;
  }

  ReaderFormula swapped_faces = kProductionFormula;
  swapped_faces.swap_source_faces = true;
  const auto wrong_faces = emulate_reader(inputs, state, swapped_faces);
  if (!wrong_faces || (wrong_faces->state == expected_state &&
                       wrong_faces->inputs == expected_inputs)) {
    return false;
  }

  ReaderFormula transposed_state = kProductionFormula;
  transposed_state.transpose_state_destination = true;
  const auto wrong_orientation =
      emulate_reader(inputs, state, transposed_state);
  if (!wrong_orientation || wrong_orientation->state == expected_state) {
    return false;
  }

  std::vector<std::uint16_t> truncated_state = expected_state;
  truncated_state.pop_back();
  std::vector<std::uint16_t> permuted_inputs = expected_inputs;
  std::swap(permuted_inputs.front(), permuted_inputs.back());
  return truncated_state != expected_state &&
         permuted_inputs != expected_inputs;
}

std::string combined_blake3(const ValidationResult &result) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, kCombinedDomain.data(), kCombinedDomain.size());
  update_text(hasher, kFixtureBlake3);
  for (const std::string &input_hash : result.input_upload_blake3) {
    update_text(hasher, input_hash);
  }
  update_text(hasher, result.state_upload_blake3);
  update_text(hasher, result.reader_arguments_blake3);
  update_text(hasher, result.compute_arguments_blake3);
  update_text(hasher, result.writer_arguments_blake3);
  update_text(hasher, result.source_trace_blake3);
  update_text(hasher, result.state_payload_blake3);
  update_text(hasher, result.input_payload_blake3);
  update_u32(hasher, kInstanceEnd);
  update_u32(hasher, kStateSourcePageCount);
  update_u32(hasher, kInputPageRowSelectionCount);
  update_u32(hasher, kFaceReadCount);
  update_u32(hasher, kPairedRowGatherCount);
  return finalize_blake3(hasher);
}

ValidationResult validate(const Fixture &fixture) {
  if (!host_layout::shape_is_valid(kShape) || !abi_negative_controls_pass()) {
    throw std::logic_error("decode ABI core controls failed");
  }
  const auto runtime_arguments = decode_abi::make_decode_runtime_arguments(
      fixture_config(), fixture_addresses(), kInstanceStart, kInstanceEnd);
  if (!runtime_arguments || !exact_runtime_vectors(*runtime_arguments)) {
    throw std::logic_error("decode runtime vector authority mismatch");
  }

  std::array<std::vector<std::uint16_t>, kInputArtifactCount> input_uploads;
  std::array<std::string, kInputArtifactCount> input_upload_blake3;
  for (std::size_t index = 0; index < fixture.inputs.size(); ++index) {
    const auto tiled = host_layout::build_native_input(
        fixture.inputs[index].values, kShape, kTokenCount, kSequenceCount,
        tilize_values);
    const auto bits = tiled ? exact_bits(*tiled) : std::nullopt;
    if (!bits) {
      throw std::runtime_error(std::string(kInputNames[index]) +
                               " host upload failed");
    }
    const std::vector<std::uint8_t> bytes = bits_to_bytes(*bits);
    input_upload_blake3[index] = blake3_hex(bytes.data(), bytes.size());
    if (input_upload_blake3[index] != kExpectedInputUploadBlake3[index]) {
      throw std::runtime_error(std::string(kInputNames[index]) +
                               " host upload identity mismatch");
    }
    input_uploads[index] = *bits;
  }

  const auto state_matrix = host_layout::build_state_upload_matrix(
      fixture.pre_state.values, kShape, kSequenceCount, kPaddedSequenceCount);
  if (!state_matrix) {
    throw std::runtime_error("state host upload failed");
  }
  const auto state_tiled = tilize_values(
      state_matrix->values, state_matrix->rows, state_matrix->columns);
  const auto state_bits = exact_bits(state_tiled);
  if (!state_bits) {
    throw std::runtime_error("state host upload BF16 conversion failed");
  }
  const std::vector<std::uint8_t> state_bytes = bits_to_bytes(*state_bits);
  const std::string state_upload_blake3 =
      blake3_hex(state_bytes.data(), state_bytes.size());
  if (state_upload_blake3 != kStateUploadBlake3) {
    throw std::runtime_error("state host upload identity mismatch");
  }

  const auto payload =
      emulate_reader(input_uploads, *state_bits, kProductionFormula);
  const std::vector<std::uint16_t> expected_state =
      independent_state_oracle(fixture.pre_state);
  const std::vector<std::uint16_t> expected_inputs =
      independent_input_oracle(fixture);
  if (!payload || payload->state != expected_state ||
      payload->inputs != expected_inputs ||
      !trace_coverage_is_exact(payload->trace) ||
      !gather_negative_controls_pass(input_uploads, *state_bits, expected_state,
                                     expected_inputs)) {
    throw std::runtime_error("decode reader source model mismatch");
  }

  ValidationResult result{
      .runtime_arguments = *runtime_arguments,
      .input_upload_blake3 = input_upload_blake3,
      .state_upload_blake3 = state_upload_blake3,
      .reader_arguments_blake3 =
          argument_blake3(kRuntimeReaderDomain, runtime_arguments->reader),
      .compute_arguments_blake3 =
          argument_blake3(kRuntimeComputeDomain, runtime_arguments->compute),
      .writer_arguments_blake3 =
          argument_blake3(kRuntimeWriterDomain, runtime_arguments->writer),
      .source_trace_blake3 = trace_blake3(payload->trace),
      .state_payload_blake3 =
          payload_blake3(kStatePayloadDomain, payload->state),
      .input_payload_blake3 =
          payload_blake3(kInputPayloadDomain, payload->inputs),
      .combined_blake3 = {},
  };
  result.combined_blake3 = combined_blake3(result);
  return result;
}

template <std::size_t Size>
std::vector<std::uint32_t>
to_vector(const std::array<std::uint32_t, Size> &values) {
  return std::vector<std::uint32_t>(values.begin(), values.end());
}

Json receipt_json(const ValidationResult &result) {
  return Json{
      {"schema_version", kSchemaVersion},
      {"target", kTarget},
      {"fixture_blake3", kFixtureBlake3},
      {"fixture_ordered_artifact_blake3", kOrderedArtifactBlake3},
      {"shape",
       {{"sequence_count", kSequenceCount},
        {"token_count", kTokenCount},
        {"head_size", kHeadSize},
        {"head_count", kHeadCount},
        {"padded_head_count", kPaddedHeadCount}}},
      {"production_source_blake3",
       {{"decode_reader", kDecodeReaderSourceBlake3},
        {"decode_compute", kDecodeComputeSourceBlake3},
        {"writer", kWriterSourceBlake3}}},
      {"runtime_arguments",
       {{"reader", to_vector(result.runtime_arguments.reader)},
        {"compute", to_vector(result.runtime_arguments.compute)},
        {"writer", to_vector(result.runtime_arguments.writer)}}},
      {"runtime_argument_blake3",
       {{"reader", result.reader_arguments_blake3},
        {"compute", result.compute_arguments_blake3},
        {"writer", result.writer_arguments_blake3}}},
      {"host_layout_blake3",
       {{"inputs", result.input_upload_blake3},
        {"state", result.state_upload_blake3}}},
      {"reader_coverage",
       {{"instance_start", kInstanceStart},
        {"instance_end", kInstanceEnd},
        {"state_source_pages", kStateSourcePageCount},
        {"input_page_row_selections", kInputPageRowSelectionCount},
        {"face_reads", kFaceReadCount},
        {"paired_row_gathers", kPairedRowGatherCount},
        {"state_values", kStateElementCount},
        {"input_values", kInputElementCount},
        {"unwritten_input_rows_included", false}}},
      {"source_trace_blake3", result.source_trace_blake3},
      {"state_payload_blake3", result.state_payload_blake3},
      {"input_payload_blake3", result.input_payload_blake3},
      {"combined_decode_reader_blake3", result.combined_blake3},
      {"device_initialized", false},
      {"non_claims", kNonClaims},
  };
}

} // namespace ttwkv7::rwkv_decode_reader

int main(int argc, char **argv) {
  using namespace ttwkv7::rwkv_decode_reader;
  if (argc != kExpectedArgumentCount) {
    std::fprintf(stderr, "usage: %s FIXTURE\n", argv[0]);
    return kInvalidArgumentStatus;
  }
  try {
    const std::string file_bytes = read_fixture_file(argv[1]);
    const Fixture fixture = parse_fixture(file_bytes);
    const ValidationResult result = validate(fixture);
    std::printf("%s\n", receipt_json(result).dump().c_str());
    return kSuccessStatus;
  } catch (const std::exception &error) {
    std::fprintf(stderr, "decode-reader validation failed: %s\n", error.what());
    return kValidationFailureStatus;
  }
}
