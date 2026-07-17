#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <limits>
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

#include "ttwkv7-host-layout.h"

namespace ttwkv7::rwkv_host_layout {

using Json = nlohmann::json;
using host_layout::Matrix;

constexpr std::uint32_t kHeadCount = 12;
constexpr std::uint32_t kHeadSize = 64;
constexpr std::uint32_t kPaddedHeadCount = 32;
constexpr std::uint32_t kHiddenSize = kHeadCount * kHeadSize;
constexpr std::uint32_t kSequenceCount = 1;
constexpr std::uint32_t kTokenCount = 1;
constexpr std::uint32_t kPaddedSequenceCount = 32;
constexpr std::uint32_t kExpectedWriterRows = 96;
constexpr std::uint32_t kExpectedWriterLogicalRows = 65;
constexpr std::uint32_t kExpectedWriterTokenRows = 1;
constexpr std::uint32_t kFaceWidth = 16;
constexpr std::uint32_t kFacesPerTileDimension = 2;
constexpr std::size_t kMatrixRank = 2;
constexpr std::size_t kPrefixTokenCount = 2;
constexpr std::size_t kNonClaimCount = 8;
constexpr std::uint32_t kBitsPerByte = 8;
constexpr std::uint32_t kBitsPerNibble = 4;
constexpr std::uint8_t kNibbleMask = 0x0f;
constexpr std::size_t kHexDigitCount = 16;
constexpr std::uint8_t kDecimalDigitCount = 10;
constexpr std::uint32_t kBf16WideningShift = 16;
constexpr std::uint32_t kFacesPerTile =
    kFacesPerTileDimension * kFacesPerTileDimension;
constexpr std::uint32_t kElementsPerFace = kFaceWidth * kFaceWidth;
constexpr std::uint32_t kElementsPerTile =
    host_layout::kTileWidth * host_layout::kTileHeight;
constexpr std::size_t kInputArtifactCount = 6;
constexpr std::size_t kVectorElementCount = kHiddenSize;
constexpr std::size_t kStateElementCount =
    static_cast<std::size_t>(kHeadCount) * kHeadSize * kHeadSize;
constexpr std::size_t kBf16Bytes = 2;
constexpr std::size_t kHexCharactersPerByte = 2;
constexpr std::size_t kDigestBytes = BLAKE3_OUT_LEN;
constexpr std::size_t kDigestHexCharacters = kDigestBytes * 2;
constexpr std::size_t kBytesPerKibibyte = 1024;
constexpr std::size_t kMaximumFixtureBytes =
    kBytesPerKibibyte * kBytesPerKibibyte;
constexpr std::size_t kExpectedFixtureBytes = 420072;
constexpr int kExpectedArgumentCount = 2;
constexpr int kSuccessStatus = 0;
constexpr int kValidationFailureStatus = 1;
constexpr int kInvalidArgumentStatus = 2;
constexpr std::uint32_t kSchemaVersion = 1;
constexpr std::uint32_t kLayerIndex = 0;
constexpr std::uint32_t kPrefixFirstToken = 1;
constexpr std::uint32_t kPrefixSecondToken = 2;
constexpr std::string_view kTarget = "ttwkv7_logical_wkv_boundary";
constexpr std::string_view kLayoutTarget = "rwkv_ttwkv7_host_layout";
constexpr std::string_view kPrecision =
    "little_endian_bf16_storage_cpu_fp32_recurrence";
constexpr std::string_view kByteOrder = "little_endian";
constexpr std::string_view kVectorOrder = "head_dimension";
constexpr std::string_view kStateOrder = "head_row_column";
constexpr std::string_view kOutputOrder = "head_row";
constexpr std::string_view kModelId = "RWKV/RWKV7-Goose-World2.8-0.1B-HF";
constexpr std::string_view kModelRevision =
    "d81965cb4e1a9f96696b4f70b84212b8f2e43216";
constexpr std::string_view kModelBlake3 =
    "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5";
constexpr std::string_view kModelSha256Sri =
    "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=";
constexpr std::uint64_t kModelByteCount = 382111072;
constexpr std::uint32_t kIntermediateSize = 3072;
constexpr std::string_view kExpectedFixtureBlake3 =
    "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
constexpr std::string_view kExpectedOrderedArtifactBlake3 =
    "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
constexpr std::string_view kFixtureHashDomain = "rwkv-ttwkv7-boundary-v1";
constexpr std::string_view kLayoutHashDomain = "rwkv-ttwkv7-host-layout-v1";
constexpr std::array<std::string_view, kInputArtifactCount> kInputNames = {
    "a", "w", "k", "v", "r", "b"};
constexpr std::array<std::string_view, kInputArtifactCount> kInputUploadNames =
    {"a_upload", "w_upload", "k_upload", "v_upload", "r_upload", "b_upload"};
constexpr std::array<std::string_view, kNonClaimCount> kNonClaims = {
    "No ttWKV7 recurrence or compute-kernel execution is established.",
    "No production reader or writer kernel execution is established.",
    "No Metalium device initialization is established.",
    "No P150 numerical correctness is established.",
    "No repaired-reader completion is established.",
    "No full-layer or full-model BF16 parity is established.",
    "No token generation or serving behavior is established.",
    "No throughput or latency claim is established.",
};

static_assert(sizeof(bfloat16) == kBf16Bytes);
static_assert(kFacesPerTile * kElementsPerFace == kElementsPerTile);
static_assert(kExpectedWriterLogicalRows ==
              kExpectedWriterTokenRows + kHeadSize);

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
    .tiles_per_head_dimension = kHeadSize / host_layout::kTileWidth,
    .head_tile_rows = kPaddedHeadCount / host_layout::kTileHeight,
    .channel_count = kHiddenSize,
};

struct Artifact {
  std::string name;
  std::vector<std::uint32_t> logical_shape;
  std::vector<std::uint8_t> bytes;
  std::vector<float> values;
  std::string blake3;
};

struct Fixture {
  std::string file_blake3;
  std::string ordered_artifact_blake3;
  std::array<Artifact, kInputArtifactCount> inputs;
  Artifact pre_state;
  Artifact expected_output;
  Artifact expected_post_state;
};

struct LayoutArtifact {
  std::string name;
  std::uint32_t rows;
  std::uint32_t columns;
  std::vector<std::uint8_t> bytes;
  std::string blake3;
};

struct LayoutReceipt {
  std::string fixture_blake3;
  std::string fixture_ordered_artifact_blake3;
  std::array<std::string, kInputArtifactCount> input_upload_blake3;
  std::string state_upload_blake3;
  std::string writer_tiled_blake3;
  std::string combined_layout_blake3;
  std::size_t input_upload_tiles;
  std::size_t state_upload_tiles;
  std::size_t writer_tiles;
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

std::string blake3_hex(const std::uint8_t *data, std::size_t size) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, data, size);
  std::array<std::uint8_t, kDigestBytes> digest{};
  blake3_hasher_finalize(&hasher, digest.data(), digest.size());
  return digest_hex(digest);
}

std::string blake3_hex(const std::vector<std::uint8_t> &bytes) {
  return blake3_hex(bytes.data(), bytes.size());
}

std::string blake3_hex(std::string_view text) {
  return blake3_hex(reinterpret_cast<const std::uint8_t *>(text.data()),
                    text.size());
}

void update_u64_little_endian(blake3_hasher &hasher, std::uint64_t value) {
  std::array<std::uint8_t, sizeof(value)> bytes{};
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    bytes[index] = static_cast<std::uint8_t>(value >> (index * kBitsPerByte));
  }
  blake3_hasher_update(&hasher, bytes.data(), bytes.size());
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
                             " has empty or odd-length hexadecimal bytes");
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
    bytes.push_back(static_cast<std::uint8_t>((*high << 4) | *low));
  }
  return bytes;
}

float decode_bf16(std::uint16_t bits) {
  return std::bit_cast<float>(static_cast<std::uint32_t>(bits)
                              << kBf16WideningShift);
}

std::uint16_t metalium_bf16_bits(float value) {
  return std::bit_cast<std::uint16_t>(bfloat16(value));
}

std::vector<float> decode_bf16_values(const std::vector<std::uint8_t> &bytes,
                                      std::string_view name) {
  if (bytes.size() % kBf16Bytes != 0) {
    throw std::runtime_error(std::string(name) +
                             " byte count is not BF16 aligned");
  }
  std::vector<float> values;
  values.reserve(bytes.size() / kBf16Bytes);
  for (std::size_t index = 0; index < bytes.size(); index += kBf16Bytes) {
    const std::uint16_t bits =
        static_cast<std::uint16_t>(bytes[index]) |
        (static_cast<std::uint16_t>(bytes[index + 1]) << kBitsPerByte);
    const float value = decode_bf16(bits);
    if (!std::isfinite(value)) {
      throw std::runtime_error(std::string(name) +
                               " contains a non-finite BF16 value");
    }
    if (metalium_bf16_bits(value) != bits) {
      throw std::runtime_error(std::string(name) +
                               " changes bits under Metalium BF16 encoding");
    }
    values.push_back(value);
  }
  return values;
}

std::vector<std::uint8_t> encode_metalium_bf16(const std::vector<float> &values,
                                               std::string_view name) {
  std::vector<std::uint8_t> bytes;
  bytes.reserve(values.size() * kBf16Bytes);
  for (const float value : values) {
    if (!std::isfinite(value)) {
      throw std::runtime_error(std::string(name) +
                               " contains a non-finite transformed value");
    }
    const std::uint16_t bits = metalium_bf16_bits(value);
    if (decode_bf16(bits) != value) {
      throw std::runtime_error(std::string(name) +
                               " is not exactly representable as BF16");
    }
    bytes.push_back(static_cast<std::uint8_t>(bits));
    bytes.push_back(static_cast<std::uint8_t>(bits >> kBitsPerByte));
  }
  return bytes;
}

std::vector<std::uint32_t> parse_shape(const Json &value,
                                       std::string_view name) {
  if (!value.is_array() || value.empty()) {
    throw std::runtime_error(std::string(name) + " shape must be nonempty");
  }
  std::vector<std::uint32_t> shape;
  shape.reserve(value.size());
  for (const Json &dimension : value) {
    const std::uint32_t parsed = dimension.get<std::uint32_t>();
    if (parsed == 0) {
      throw std::runtime_error(std::string(name) +
                               " shape contains a zero dimension");
    }
    shape.push_back(parsed);
  }
  return shape;
}

std::size_t shape_elements(const std::vector<std::uint32_t> &shape,
                           std::string_view name) {
  std::size_t elements = 1;
  for (const std::uint32_t dimension : shape) {
    const auto product = host_layout::checked_product(elements, dimension);
    if (!product) {
      throw std::runtime_error(std::string(name) + " shape overflows");
    }
    elements = *product;
  }
  return elements;
}

Artifact parse_artifact(const Json &value, std::string_view expected_name,
                        const std::vector<std::uint32_t> &expected_shape) {
  if (!value.is_object()) {
    throw std::runtime_error(std::string(expected_name) +
                             " artifact must be an object");
  }
  const std::string name = value.at("name").get<std::string>();
  if (name != expected_name) {
    throw std::runtime_error("artifact order expected " +
                             std::string(expected_name) + ", found " + name);
  }
  const std::vector<std::uint32_t> shape =
      parse_shape(value.at("logical_shape"), name);
  if (shape != expected_shape) {
    throw std::runtime_error(name + " has an unexpected logical shape");
  }
  const std::size_t expected_elements = shape_elements(shape, name);
  const std::size_t element_count =
      value.at("element_count").get<std::size_t>();
  const std::size_t byte_count = value.at("byte_count").get<std::size_t>();
  if (element_count != expected_elements ||
      byte_count != expected_elements * kBf16Bytes) {
    throw std::runtime_error(name +
                             " has an inconsistent element or byte count");
  }
  const std::string bytes_hex = value.at("bytes_hex").get<std::string>();
  std::vector<std::uint8_t> bytes = decode_lowercase_hex(bytes_hex, name);
  if (bytes.size() != byte_count) {
    throw std::runtime_error(name + " hexadecimal byte count changed");
  }
  const std::string expected_blake3 = value.at("blake3").get<std::string>();
  if (expected_blake3.size() != kDigestHexCharacters ||
      blake3_hex(bytes) != expected_blake3) {
    throw std::runtime_error(name + " BLAKE3 mismatch");
  }
  std::vector<float> values = decode_bf16_values(bytes, name);
  return Artifact{
      .name = name,
      .logical_shape = shape,
      .bytes = std::move(bytes),
      .values = std::move(values),
      .blake3 = expected_blake3,
  };
}

void require_string(const Json &object, std::string_view key,
                    std::string_view expected) {
  const std::string actual = object.at(std::string(key)).get<std::string>();
  if (actual != expected) {
    throw std::runtime_error(std::string(key) + " authority mismatch");
  }
}

void validate_metadata(const Json &root) {
  if (!root.is_object() ||
      root.at("schema_version").get<std::uint32_t>() != kSchemaVersion ||
      root.at("layer_index").get<std::uint32_t>() != kLayerIndex) {
    throw std::runtime_error("fixture schema or layer authority mismatch");
  }
  require_string(root, "target", kTarget);
  require_string(root, "arithmetic_precision", kPrecision);
  require_string(root, "byte_order", kByteOrder);
  require_string(root, "vector_order", kVectorOrder);
  require_string(root, "state_order", kStateOrder);
  require_string(root, "output_order", kOutputOrder);

  const Json &model = root.at("model");
  require_string(model, "model_id", kModelId);
  require_string(model, "revision", kModelRevision);
  require_string(model, "blake3", kModelBlake3);
  require_string(model, "sha256_sri", kModelSha256Sri);
  if (model.at("byte_count").get<std::uint64_t>() != kModelByteCount) {
    throw std::runtime_error("model byte-count authority mismatch");
  }

  const Json &dimensions = root.at("dimensions");
  if (dimensions.at("head_count").get<std::uint32_t>() != kHeadCount ||
      dimensions.at("head_size").get<std::uint32_t>() != kHeadSize ||
      dimensions.at("hidden_size").get<std::uint32_t>() != kHiddenSize ||
      dimensions.at("intermediate_size").get<std::uint32_t>() !=
          kIntermediateSize) {
    throw std::runtime_error("fixture dimension authority mismatch");
  }
  const std::array<std::uint32_t, kPrefixTokenCount> expected_prefix = {
      kPrefixFirstToken, kPrefixSecondToken};
  if (root.at("prefix_token_ids") != expected_prefix ||
      root.at("input_order") != kInputNames) {
    throw std::runtime_error("fixture prefix or input order mismatch");
  }
}

void update_named_artifact(blake3_hasher &hasher, const Artifact &artifact) {
  update_u64_little_endian(hasher, artifact.name.size());
  blake3_hasher_update(&hasher, artifact.name.data(), artifact.name.size());
  update_u64_little_endian(hasher, artifact.logical_shape.size());
  for (const std::uint32_t dimension : artifact.logical_shape) {
    update_u64_little_endian(hasher, dimension);
  }
  update_u64_little_endian(hasher, artifact.values.size());
  blake3_hasher_update(&hasher, artifact.bytes.data(), artifact.bytes.size());
}

std::string ordered_artifact_blake3(const Fixture &fixture) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, kFixtureHashDomain.data(),
                       kFixtureHashDomain.size());
  for (const Artifact &artifact : fixture.inputs) {
    update_named_artifact(hasher, artifact);
  }
  update_named_artifact(hasher, fixture.pre_state);
  update_named_artifact(hasher, fixture.expected_output);
  update_named_artifact(hasher, fixture.expected_post_state);
  std::array<std::uint8_t, kDigestBytes> digest{};
  blake3_hasher_finalize(&hasher, digest.data(), digest.size());
  return digest_hex(digest);
}

std::string read_fixture_file(const std::filesystem::path &path) {
  std::error_code error;
  if (!std::filesystem::is_regular_file(path, error) || error) {
    throw std::runtime_error("fixture path must be a readable regular file");
  }
  const std::uintmax_t file_size = std::filesystem::file_size(path, error);
  if (error || file_size == 0 || file_size > kMaximumFixtureBytes) {
    throw std::runtime_error("fixture file size is outside the reviewed bound");
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

Fixture parse_fixture(std::string_view file_bytes) {
  if (file_bytes.size() != kExpectedFixtureBytes) {
    throw std::runtime_error("fixture byte count does not match the authority");
  }
  const Json root = Json::parse(file_bytes.begin(), file_bytes.end());
  validate_metadata(root);

  const Json &input_artifacts = root.at("input_artifacts");
  if (!input_artifacts.is_array() ||
      input_artifacts.size() != kInputArtifactCount) {
    throw std::runtime_error("fixture must contain six input artifacts");
  }
  const std::vector<std::uint32_t> vector_shape = {kHeadCount, kHeadSize};
  const std::vector<std::uint32_t> state_shape = {kHeadCount, kHeadSize,
                                                  kHeadSize};
  std::array<Artifact, kInputArtifactCount> inputs;
  for (std::size_t index = 0; index < inputs.size(); ++index) {
    inputs[index] = parse_artifact(input_artifacts[index], kInputNames[index],
                                   vector_shape);
  }

  Fixture fixture{
      .file_blake3 = blake3_hex(file_bytes),
      .ordered_artifact_blake3 =
          root.at("ordered_artifact_blake3").get<std::string>(),
      .inputs = std::move(inputs),
      .pre_state = parse_artifact(root.at("pre_state_artifact"), "pre_state",
                                  state_shape),
      .expected_output = parse_artifact(root.at("expected_output_artifact"),
                                        "expected_output", vector_shape),
      .expected_post_state =
          parse_artifact(root.at("expected_post_state_artifact"),
                         "expected_post_state", state_shape),
  };
  const std::string computed_ordered = ordered_artifact_blake3(fixture);
  if (fixture.ordered_artifact_blake3 != kExpectedOrderedArtifactBlake3 ||
      computed_ordered != fixture.ordered_artifact_blake3) {
    throw std::runtime_error("ordered fixture artifact BLAKE3 mismatch");
  }
  if (fixture.file_blake3 != kExpectedFixtureBlake3) {
    throw std::runtime_error("whole fixture BLAKE3 mismatch");
  }
  return fixture;
}

std::vector<float> tilize_values(const std::vector<float> &values,
                                 std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(values),
                        std::array<std::uint32_t, kMatrixRank>{rows, columns},
                        TensorLayoutType::LIN_ROW_MAJOR,
                        TensorLayoutType::TILED_NFACES);
}

std::vector<float> untilize_values(const std::vector<float> &values,
                                   std::uint32_t rows, std::uint32_t columns) {
  return convert_layout(tt::stl::Span<const float>(values),
                        std::array<std::uint32_t, kMatrixRank>{rows, columns},
                        TensorLayoutType::TILED_NFACES,
                        TensorLayoutType::LIN_ROW_MAJOR);
}

std::optional<std::vector<float>> independent_tilize(const Matrix &matrix) {
  if (matrix.rows == 0 || matrix.columns == 0 ||
      matrix.rows % host_layout::kTileHeight != 0 ||
      matrix.columns % host_layout::kTileWidth != 0 ||
      matrix.values.size() !=
          static_cast<std::size_t>(matrix.rows) * matrix.columns) {
    return std::nullopt;
  }
  std::vector<float> tiled;
  tiled.reserve(matrix.values.size());
  const std::uint32_t tile_rows = matrix.rows / host_layout::kTileHeight;
  const std::uint32_t tile_columns = matrix.columns / host_layout::kTileWidth;
  for (std::uint32_t tile_row = 0; tile_row < tile_rows; ++tile_row) {
    for (std::uint32_t tile_column = 0; tile_column < tile_columns;
         ++tile_column) {
      for (std::uint32_t face_row = 0; face_row < kFacesPerTileDimension;
           ++face_row) {
        for (std::uint32_t face_column = 0;
             face_column < kFacesPerTileDimension; ++face_column) {
          for (std::uint32_t row = 0; row < kFaceWidth; ++row) {
            for (std::uint32_t column = 0; column < kFaceWidth; ++column) {
              const std::uint32_t source_row =
                  tile_row * host_layout::kTileHeight + face_row * kFaceWidth +
                  row;
              const std::uint32_t source_column =
                  tile_column * host_layout::kTileWidth +
                  face_column * kFaceWidth + column;
              tiled.push_back(
                  matrix.values[static_cast<std::size_t>(source_row) *
                                    matrix.columns +
                                source_column]);
            }
          }
        }
      }
    }
  }
  return tiled;
}

bool host_core_negative_controls_pass() {
  Shape invalid_padding = kShape;
  invalid_padding.padded_head_count = kHeadCount;
  if (host_layout::shape_is_valid(invalid_padding)) {
    return false;
  }
  Shape invalid_channels = kShape;
  --invalid_channels.channel_count;
  if (host_layout::shape_is_valid(invalid_channels)) {
    return false;
  }

  const std::vector<float> logical_input(kVectorElementCount, 0.0F);
  std::vector<float> short_input = logical_input;
  short_input.pop_back();
  if (host_layout::build_padded_input_blocks(short_input, kShape, kTokenCount,
                                             kSequenceCount) ||
      host_layout::build_padded_input_blocks(logical_input, kShape, 0,
                                             kSequenceCount)) {
    return false;
  }
  const auto wrong_size_tilizer = [](const std::vector<float> &, std::uint32_t,
                                     std::uint32_t) {
    return std::vector<float>{};
  };
  if (host_layout::build_native_input(logical_input, kShape, kTokenCount,
                                      kSequenceCount, wrong_size_tilizer)) {
    return false;
  }

  const std::vector<float> short_state(kStateElementCount - 1, 0.0F);
  const std::vector<float> state(kStateElementCount, 0.0F);
  if (host_layout::build_state_upload_matrix(
          short_state, kShape, kSequenceCount, kPaddedSequenceCount) ||
      host_layout::build_state_upload_matrix(state, kShape, kSequenceCount,
                                             kPaddedSequenceCount - 1)) {
    return false;
  }

  if (host_layout::derive_writer_layout(kShape, kSequenceCount, 0)) {
    return false;
  }
  const auto writer_layout =
      host_layout::derive_writer_layout(kShape, kSequenceCount, kTokenCount);
  if (!writer_layout ||
      host_layout::writer_output_index(*writer_layout, kShape, 0, 0, kHeadCount,
                                       0, kTokenCount) ||
      host_layout::writer_state_index(*writer_layout, kShape, kSequenceCount, 0,
                                      0, 0, kSequenceCount)) {
    return false;
  }

  const Matrix invalid_matrix{
      .rows = kHeadCount,
      .columns = kHeadSize,
      .values = logical_input,
  };
  return !independent_tilize(invalid_matrix);
}

void require_equal(const std::vector<float> &expected,
                   const std::vector<float> &actual, std::string_view context) {
  if (expected.size() != actual.size()) {
    throw std::runtime_error(std::string(context) + " element count changed");
  }
  for (std::size_t index = 0; index < expected.size(); ++index) {
    if (expected[index] != actual[index]) {
      throw std::runtime_error(std::string(context) + " differs at element " +
                               std::to_string(index));
    }
  }
}

void require_zero_range(const std::vector<float> &values, std::size_t begin,
                        std::size_t end, std::string_view context) {
  if (begin > end || end > values.size()) {
    throw std::runtime_error(std::string(context) + " zero range is invalid");
  }
  for (std::size_t index = begin; index < end; ++index) {
    if (values[index] != 0.0F) {
      throw std::runtime_error(std::string(context) +
                               " padding is nonzero at element " +
                               std::to_string(index));
    }
  }
}

LayoutArtifact validate_tiled_matrix(std::string name, const Matrix &row_major,
                                     const std::vector<float> &metalium_tiled) {
  const auto independent = independent_tilize(row_major);
  if (!independent) {
    throw std::runtime_error(name + " has invalid tiled dimensions");
  }
  require_equal(*independent, metalium_tiled,
                name + " independent tiled-NFACES");
  const std::vector<std::uint8_t> bytes =
      encode_metalium_bf16(metalium_tiled, name);
  const std::vector<float> quantized = decode_bf16_values(bytes, name);
  require_equal(metalium_tiled, quantized, name + " BF16 round trip");
  const std::vector<float> round_trip =
      untilize_values(quantized, row_major.rows, row_major.columns);
  require_equal(row_major.values, round_trip, name + " untilize round trip");
  return LayoutArtifact{
      .name = std::move(name),
      .rows = row_major.rows,
      .columns = row_major.columns,
      .bytes = bytes,
      .blake3 = blake3_hex(bytes),
  };
}

void update_layout_artifact(blake3_hasher &hasher,
                            const LayoutArtifact &artifact) {
  update_u64_little_endian(hasher, artifact.name.size());
  blake3_hasher_update(&hasher, artifact.name.data(), artifact.name.size());
  update_u64_little_endian(hasher, kMatrixRank);
  update_u64_little_endian(hasher, artifact.rows);
  update_u64_little_endian(hasher, artifact.columns);
  update_u64_little_endian(hasher, artifact.bytes.size() / kBf16Bytes);
  blake3_hasher_update(&hasher, artifact.bytes.data(), artifact.bytes.size());
}

std::string combined_layout_blake3(
    const std::array<LayoutArtifact, kInputArtifactCount> &inputs,
    const LayoutArtifact &state, const LayoutArtifact &writer) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, kLayoutHashDomain.data(),
                       kLayoutHashDomain.size());
  for (const LayoutArtifact &input : inputs) {
    update_layout_artifact(hasher, input);
  }
  update_layout_artifact(hasher, state);
  update_layout_artifact(hasher, writer);
  std::array<std::uint8_t, kDigestBytes> digest{};
  blake3_hasher_finalize(&hasher, digest.data(), digest.size());
  return digest_hex(digest);
}

LayoutReceipt validate_layout(const Fixture &fixture) {
  if (!host_layout::shape_is_valid(kShape) ||
      !host_core_negative_controls_pass()) {
    throw std::logic_error("shared host-layout core controls failed");
  }

  std::array<LayoutArtifact, kInputArtifactCount> input_uploads;
  std::size_t input_upload_tiles = 0;
  for (std::size_t index = 0; index < fixture.inputs.size(); ++index) {
    const auto blocks = host_layout::build_padded_input_blocks(
        fixture.inputs[index].values, kShape, kTokenCount, kSequenceCount);
    const auto tiled = host_layout::build_native_input(
        fixture.inputs[index].values, kShape, kTokenCount, kSequenceCount,
        tilize_values);
    if (!blocks || blocks->size() != kSequenceCount || !tiled) {
      throw std::runtime_error(std::string(kInputNames[index]) +
                               " input host layout failed");
    }
    const Matrix &block = blocks->front();
    require_equal(fixture.inputs[index].values,
                  std::vector<float>(block.values.begin(),
                                     block.values.begin() +
                                         fixture.inputs[index].values.size()),
                  std::string(kInputNames[index]) + " logical rows");
    require_zero_range(block.values, fixture.inputs[index].values.size(),
                       block.values.size(),
                       std::string(kInputNames[index]) + " head padding");
    input_uploads[index] = validate_tiled_matrix(
        std::string(kInputUploadNames[index]), block, *tiled);
    input_upload_tiles += tiled->size() / kElementsPerTile;
  }

  const auto state_matrix = host_layout::build_state_upload_matrix(
      fixture.pre_state.values, kShape, kSequenceCount, kPaddedSequenceCount);
  if (!state_matrix) {
    throw std::runtime_error("retained state host layout failed");
  }
  require_equal(fixture.pre_state.values,
                std::vector<float>(state_matrix->values.begin(),
                                   state_matrix->values.begin() +
                                       fixture.pre_state.values.size()),
                "retained state logical row");
  require_zero_range(state_matrix->values, fixture.pre_state.values.size(),
                     state_matrix->values.size(), "retained state padding");
  const std::vector<float> state_tiled = tilize_values(
      state_matrix->values, state_matrix->rows, state_matrix->columns);
  const LayoutArtifact state_upload =
      validate_tiled_matrix("pre_state_upload", *state_matrix, state_tiled);

  const auto writer_layout =
      host_layout::derive_writer_layout(kShape, kSequenceCount, kTokenCount);
  if (!writer_layout || writer_layout->token_rows != kExpectedWriterTokenRows ||
      writer_layout->logical_rows != kExpectedWriterLogicalRows ||
      writer_layout->padded_rows != kExpectedWriterRows ||
      writer_layout->columns != kHiddenSize) {
    throw std::runtime_error("writer layout dimensions changed");
  }
  Matrix writer_matrix{
      .rows = writer_layout->padded_rows,
      .columns = writer_layout->columns,
      .values = std::vector<float>(
          static_cast<std::size_t>(writer_layout->padded_rows) *
              writer_layout->columns,
          0.0F),
  };
  std::vector<bool> written(
      static_cast<std::size_t>(writer_layout->logical_rows) *
          writer_layout->columns,
      false);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t dimension = 0; dimension < kHeadSize; ++dimension) {
      const auto destination = host_layout::writer_output_index(
          *writer_layout, kShape, 0, 0, head, dimension, kTokenCount);
      const std::size_t source =
          static_cast<std::size_t>(head) * kHeadSize + dimension;
      if (!destination || *destination >= written.size() ||
          written[*destination]) {
        throw std::runtime_error("writer output mapping is not bijective");
      }
      writer_matrix.values[*destination] =
          fixture.expected_output.values[source];
      written[*destination] = true;
    }
  }
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t row = 0; row < kHeadSize; ++row) {
      for (std::uint32_t column = 0; column < kHeadSize; ++column) {
        const auto destination = host_layout::writer_state_index(
            *writer_layout, kShape, 0, head, row, column, kSequenceCount);
        const std::size_t source =
            (static_cast<std::size_t>(head) * kHeadSize + row) * kHeadSize +
            column;
        if (!destination || *destination >= written.size() ||
            written[*destination]) {
          throw std::runtime_error("writer state mapping is not bijective");
        }
        writer_matrix.values[*destination] =
            fixture.expected_post_state.values[source];
        written[*destination] = true;
      }
    }
  }
  for (std::size_t index = 0; index < written.size(); ++index) {
    if (!written[index]) {
      throw std::runtime_error(
          "writer logical matrix contains an unwritten element");
    }
  }
  require_zero_range(writer_matrix.values, written.size(),
                     writer_matrix.values.size(), "writer tail");

  const std::vector<float> writer_tiled = tilize_values(
      writer_matrix.values, writer_matrix.rows, writer_matrix.columns);
  const LayoutArtifact writer =
      validate_tiled_matrix("expected_writer", writer_matrix, writer_tiled);
  const std::vector<float> writer_round_trip =
      untilize_values(writer_tiled, writer_matrix.rows, writer_matrix.columns);
  std::vector<float> extracted_output(kVectorElementCount, 0.0F);
  std::vector<float> extracted_state(kStateElementCount, 0.0F);
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t dimension = 0; dimension < kHeadSize; ++dimension) {
      const auto source = host_layout::writer_output_index(
          *writer_layout, kShape, 0, 0, head, dimension, kTokenCount);
      if (!source) {
        throw std::logic_error("writer output inverse index is invalid");
      }
      extracted_output[static_cast<std::size_t>(head) * kHeadSize + dimension] =
          writer_round_trip[*source];
    }
  }
  for (std::uint32_t head = 0; head < kHeadCount; ++head) {
    for (std::uint32_t row = 0; row < kHeadSize; ++row) {
      for (std::uint32_t column = 0; column < kHeadSize; ++column) {
        const auto source = host_layout::writer_state_index(
            *writer_layout, kShape, 0, head, row, column, kSequenceCount);
        if (!source) {
          throw std::logic_error("writer state inverse index is invalid");
        }
        const std::size_t destination =
            (static_cast<std::size_t>(head) * kHeadSize + row) * kHeadSize +
            column;
        extracted_state[destination] = writer_round_trip[*source];
      }
    }
  }
  require_equal(fixture.expected_output.values, extracted_output,
                "writer output inverse");
  require_equal(fixture.expected_post_state.values, extracted_state,
                "writer state inverse");

  std::array<std::string, kInputArtifactCount> input_hashes;
  for (std::size_t index = 0; index < input_hashes.size(); ++index) {
    input_hashes[index] = input_uploads[index].blake3;
  }
  return LayoutReceipt{
      .fixture_blake3 = fixture.file_blake3,
      .fixture_ordered_artifact_blake3 = fixture.ordered_artifact_blake3,
      .input_upload_blake3 = std::move(input_hashes),
      .state_upload_blake3 = state_upload.blake3,
      .writer_tiled_blake3 = writer.blake3,
      .combined_layout_blake3 =
          combined_layout_blake3(input_uploads, state_upload, writer),
      .input_upload_tiles = input_upload_tiles,
      .state_upload_tiles = state_tiled.size() / kElementsPerTile,
      .writer_tiles = writer_tiled.size() / kElementsPerTile,
  };
}

Json receipt_json(const LayoutReceipt &receipt) {
  Json output;
  output["schema_version"] = kSchemaVersion;
  output["target"] = kLayoutTarget;
  output["fixture_blake3"] = receipt.fixture_blake3;
  output["fixture_ordered_artifact_blake3"] =
      receipt.fixture_ordered_artifact_blake3;
  output["dimensions"] = {
      {"head_count", kHeadCount},
      {"head_size", kHeadSize},
      {"padded_head_count", kPaddedHeadCount},
      {"hidden_size", kHiddenSize},
      {"sequence_count", kSequenceCount},
      {"token_count", kTokenCount},
      {"padded_sequence_count", kPaddedSequenceCount},
      {"writer_rows", kExpectedWriterRows},
      {"writer_columns", kHiddenSize},
  };
  output["input_upload_blake3"] = receipt.input_upload_blake3;
  output["state_upload_blake3"] = receipt.state_upload_blake3;
  output["writer_tiled_blake3"] = receipt.writer_tiled_blake3;
  output["combined_layout_blake3"] = receipt.combined_layout_blake3;
  output["tile_counts"] = {
      {"input_uploads", receipt.input_upload_tiles},
      {"state_upload", receipt.state_upload_tiles},
      {"writer", receipt.writer_tiles},
  };
  output["metalium_layout"] = "TILED_NFACES";
  output["independent_face_order"] =
      "top_left_top_right_bottom_left_bottom_right";
  output["device_initialized"] = false;
  output["non_claims"] = kNonClaims;
  return output;
}

} // namespace ttwkv7::rwkv_host_layout

int main(int argc, char **argv) {
  using namespace ttwkv7::rwkv_host_layout;
  if (argc != kExpectedArgumentCount) {
    std::fprintf(stderr, "usage: %s FIXTURE_JSON\n", argv[0]);
    return kInvalidArgumentStatus;
  }
  try {
    const std::string file_bytes = read_fixture_file(argv[1]);
    const Fixture fixture = parse_fixture(file_bytes);
    const LayoutReceipt receipt = validate_layout(fixture);
    std::printf("%s\n", receipt_json(receipt).dump().c_str());
    return kSuccessStatus;
  } catch (const std::exception &error) {
    std::fprintf(stderr, "rwkv-ttwkv7 host-layout validation failed: %s\n",
                 error.what());
    return kValidationFailureStatus;
  }
}
