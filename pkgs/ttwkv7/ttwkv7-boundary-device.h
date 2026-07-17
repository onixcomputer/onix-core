#pragma once

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include <blake3.h>
#include <nlohmann/json.hpp>

namespace ttwkv7::boundary_device {

using Json = nlohmann::json;

constexpr std::uint32_t kSchemaVersion = 1;
constexpr std::uint32_t kLayerIndex = 0;
constexpr std::uint32_t kHeadCount = 12;
constexpr std::uint32_t kHeadSize = 64;
constexpr std::uint32_t kHiddenSize = kHeadCount * kHeadSize;
constexpr std::uint32_t kIntermediateSize = 3072;
constexpr std::uint32_t kSequenceCount = 1;
constexpr std::uint32_t kTokenCount = 1;
constexpr std::uint32_t kPaddedHeadCount = 32;
constexpr std::uint32_t kWriterRowCount = 96;
constexpr std::uint32_t kWriterColumnCount = kHiddenSize;
constexpr std::uint32_t kPrefixTokenCount = 2;
constexpr std::uint32_t kPrefixFirstToken = 1;
constexpr std::uint32_t kPrefixSecondToken = 2;
constexpr std::uint32_t kBitsPerByte = 8;
constexpr std::uint32_t kBitsPerNibble = 4;
constexpr std::uint32_t kBf16WideningShift = 16;
constexpr std::uint8_t kNibbleMask = 0x0f;
constexpr std::uint8_t kDecimalDigitCount = 10;
constexpr std::size_t kInputArtifactCount = 6;
constexpr std::size_t kBf16Bytes = 2;
constexpr std::size_t kHexCharactersPerByte = 2;
constexpr std::size_t kDigestBytes = BLAKE3_OUT_LEN;
constexpr std::size_t kDigestHexCharacters = kDigestBytes * 2;
constexpr std::size_t kHexDigitCount = 16;
constexpr std::size_t kExpectedFixtureBytes = 420072;
constexpr std::size_t kVectorElementCount = kHiddenSize;
constexpr std::size_t kStateElementCount =
    static_cast<std::size_t>(kHeadCount) * kHeadSize * kHeadSize;
constexpr std::size_t kWriterElementCount =
    static_cast<std::size_t>(kWriterRowCount) * kWriterColumnCount;
constexpr std::size_t kReviewedVectorElementCount = 768;
constexpr std::size_t kReviewedStateElementCount = 49152;
constexpr std::size_t kReviewedWriterElementCount = 73728;
constexpr std::uint16_t kPositiveInfinityBf16 = 0x7f80;
constexpr double kNmseDenominatorFloor = 1.0e-12;
constexpr double kPccDenominatorFloor = 1.0e-12;
constexpr double kBoundaryNmseCeiling = 6.0e-2;
constexpr std::string_view kTarget = "ttwkv7_logical_wkv_boundary";
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
constexpr std::string_view kExpectedFixtureBlake3 =
    "731f44866c869300ca330f703f1adad4c3ae7ee62b832fa881a6bf4ea90211cd";
constexpr std::string_view kExpectedOrderedArtifactBlake3 =
    "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
constexpr std::string_view kFixtureHashDomain = "rwkv-ttwkv7-boundary-v1";
constexpr std::string_view kObservedOutputRole = "observed_output_bf16";
constexpr std::string_view kObservedPostStateRole = "observed_post_state_bf16";
constexpr std::string_view kWriterRawRole = "writer_raw_bf16";
constexpr std::array<std::string_view, kInputArtifactCount> kInputNames = {
    "a", "w", "k", "v", "r", "b"};
constexpr std::array<std::string_view, kInputArtifactCount>
    kExpectedInputBlake3 = {
        "2f2bec8195c8fca1027cdb8ef9421921643cc97db9404efe84b5139432096f89",
        "e549e829df1f6a05c9e8cbbc0b1e08d078196de57731f54a16cfcc4c9849a0ee",
        "4b0248fce75e5ff0d462be2edee6c16c1f2e2f68f1b9f5dbf696e9b3d1f7699b",
        "813277dddaee3ee19e87ede402bd65fa0393073c9fb86fb12096d1531676c68f",
        "63a08981b8cf0c852cc273e1626ab8aa77d19b141746f729af7cf269de41893d",
        "ad9f5a87a3dcfd04aebef24e0faebdfae30ec06d27369d2ff77fef90c9d38f66",
};
constexpr std::string_view kExpectedPreStateBlake3 =
    "be643f1302ec76ea76ada70b24a830a3398bc463a39915226c61fcf8f67b52cd";
constexpr std::string_view kExpectedOutputBlake3 =
    "9af55cd740a0534c91e6656da5e0fca63386e06ded01d183157d07cba6ea50e8";
constexpr std::string_view kExpectedPostStateBlake3 =
    "c76c943bab4cda028b5edae8393919ae3f93f35b79b6a02648d4617e21b414d6";

static_assert(kExpectedFixtureBlake3.size() == kDigestHexCharacters);
static_assert(kExpectedOrderedArtifactBlake3.size() == kDigestHexCharacters);
static_assert(kVectorElementCount == kReviewedVectorElementCount);
static_assert(kStateElementCount == kReviewedStateElementCount);
static_assert(kWriterElementCount == kReviewedWriterElementCount);

struct Artifact {
  std::string name;
  std::vector<std::uint32_t> logical_shape;
  std::vector<std::uint8_t> bytes;
  std::vector<std::uint16_t> bits;
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

struct Metrics {
  double pcc;
  double nmse;
  double maximum_absolute_error;
  std::size_t exact_bit_mismatch_count;
  bool finite;
};

struct Comparison {
  Metrics output;
  Metrics post_state;
  double nmse_ceiling;
  bool passed;
};

struct ArtifactEvidence {
  std::string role;
  std::size_t element_count;
  std::size_t byte_count;
  std::string blake3;
};

inline std::string
digest_hex(const std::array<std::uint8_t, kDigestBytes> &digest) {
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

inline std::string finalize_blake3(blake3_hasher &hasher) {
  std::array<std::uint8_t, kDigestBytes> digest{};
  blake3_hasher_finalize(&hasher, digest.data(), digest.size());
  return digest_hex(digest);
}

inline std::string blake3_hex(const std::uint8_t *data, std::size_t size) {
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);
  blake3_hasher_update(&hasher, data, size);
  return finalize_blake3(hasher);
}

inline std::string blake3_hex(std::string_view text) {
  return blake3_hex(reinterpret_cast<const std::uint8_t *>(text.data()),
                    text.size());
}

inline std::string blake3_hex(const std::vector<std::uint8_t> &bytes) {
  return blake3_hex(bytes.data(), bytes.size());
}

inline void update_u64(blake3_hasher &hasher, std::uint64_t value) {
  std::array<std::uint8_t, sizeof(value)> bytes{};
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    bytes[index] = static_cast<std::uint8_t>(value >> (index * kBitsPerByte));
  }
  blake3_hasher_update(&hasher, bytes.data(), bytes.size());
}

inline std::optional<std::uint8_t> lowercase_hex_value(char character) {
  if (character >= '0' && character <= '9') {
    return static_cast<std::uint8_t>(character - '0');
  }
  if (character >= 'a' && character <= 'f') {
    return static_cast<std::uint8_t>(character - 'a' + kDecimalDigitCount);
  }
  return std::nullopt;
}

inline std::vector<std::uint8_t> decode_lowercase_hex(std::string_view text,
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
    bytes.push_back(
        static_cast<std::uint8_t>((*high << kBitsPerNibble) | *low));
  }
  return bytes;
}

inline float decode_bf16(std::uint16_t bits) {
  return std::bit_cast<float>(static_cast<std::uint32_t>(bits)
                              << kBf16WideningShift);
}

inline std::vector<std::uint16_t>
decode_bf16_bits(const std::vector<std::uint8_t> &bytes,
                 std::string_view name) {
  if (bytes.size() % kBf16Bytes != 0) {
    throw std::runtime_error(std::string(name) +
                             " byte count is not BF16 aligned");
  }
  std::vector<std::uint16_t> bits;
  bits.reserve(bytes.size() / kBf16Bytes);
  for (std::size_t index = 0; index < bytes.size(); index += kBf16Bytes) {
    bits.push_back(
        static_cast<std::uint16_t>(bytes[index]) |
        (static_cast<std::uint16_t>(bytes[index + 1]) << kBitsPerByte));
  }
  return bits;
}

inline std::vector<float>
decode_bf16_values(std::span<const std::uint16_t> bits, std::string_view name) {
  std::vector<float> values;
  values.reserve(bits.size());
  for (const std::uint16_t value_bits : bits) {
    const float value = decode_bf16(value_bits);
    if (!std::isfinite(value)) {
      throw std::runtime_error(std::string(name) +
                               " contains a non-finite BF16 value");
    }
    values.push_back(value);
  }
  return values;
}

inline std::vector<std::uint8_t>
encode_bf16_bytes(std::span<const std::uint16_t> bits) {
  std::vector<std::uint8_t> bytes;
  bytes.reserve(bits.size() * kBf16Bytes);
  for (const std::uint16_t value : bits) {
    bytes.push_back(static_cast<std::uint8_t>(value));
    bytes.push_back(static_cast<std::uint8_t>(value >> kBitsPerByte));
  }
  return bytes;
}

inline std::vector<std::uint32_t> parse_shape(const Json &value,
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

inline std::size_t shape_elements(const std::vector<std::uint32_t> &shape,
                                  std::string_view name) {
  std::size_t elements = 1;
  for (const std::uint32_t dimension : shape) {
    if (dimension > std::numeric_limits<std::size_t>::max() / elements) {
      throw std::runtime_error(std::string(name) + " shape overflows");
    }
    elements *= dimension;
  }
  return elements;
}

inline Artifact parse_artifact(const Json &value,
                               std::string_view expected_name,
                               const std::vector<std::uint32_t> &expected_shape,
                               std::string_view expected_blake3) {
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
  std::vector<std::uint8_t> bytes =
      decode_lowercase_hex(value.at("bytes_hex").get<std::string>(), name);
  if (bytes.size() != byte_count) {
    throw std::runtime_error(name + " hexadecimal byte count changed");
  }
  const std::string stated_blake3 = value.at("blake3").get<std::string>();
  const std::string computed_blake3 = blake3_hex(bytes);
  if (stated_blake3 != expected_blake3 || computed_blake3 != expected_blake3) {
    throw std::runtime_error(name + " BLAKE3 mismatch");
  }
  std::vector<std::uint16_t> bits = decode_bf16_bits(bytes, name);
  std::vector<float> values = decode_bf16_values(bits, name);
  return Artifact{
      .name = name,
      .logical_shape = shape,
      .bytes = std::move(bytes),
      .bits = std::move(bits),
      .values = std::move(values),
      .blake3 = computed_blake3,
  };
}

inline void require_string(const Json &object, std::string_view key,
                           std::string_view expected) {
  const std::string actual = object.at(std::string(key)).get<std::string>();
  if (actual != expected) {
    throw std::runtime_error(std::string(key) + " authority mismatch");
  }
}

inline void validate_metadata(const Json &root) {
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

inline void update_named_artifact(blake3_hasher &hasher,
                                  const Artifact &artifact) {
  update_u64(hasher, artifact.name.size());
  blake3_hasher_update(&hasher, artifact.name.data(), artifact.name.size());
  update_u64(hasher, artifact.logical_shape.size());
  for (const std::uint32_t dimension : artifact.logical_shape) {
    update_u64(hasher, dimension);
  }
  update_u64(hasher, artifact.bits.size());
  blake3_hasher_update(&hasher, artifact.bytes.data(), artifact.bytes.size());
}

inline std::string ordered_artifact_blake3(const Fixture &fixture) {
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
  return finalize_blake3(hasher);
}

inline Fixture parse_fixture(std::string_view file_bytes) {
  if (file_bytes.size() != kExpectedFixtureBytes) {
    throw std::runtime_error("fixture byte count does not match the authority");
  }
  if (blake3_hex(file_bytes) != kExpectedFixtureBlake3) {
    throw std::runtime_error("whole fixture BLAKE3 mismatch");
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
                                   vector_shape, kExpectedInputBlake3[index]);
  }

  Fixture fixture{
      .file_blake3 = std::string(kExpectedFixtureBlake3),
      .ordered_artifact_blake3 =
          root.at("ordered_artifact_blake3").get<std::string>(),
      .inputs = std::move(inputs),
      .pre_state = parse_artifact(root.at("pre_state_artifact"), "pre_state",
                                  state_shape, kExpectedPreStateBlake3),
      .expected_output =
          parse_artifact(root.at("expected_output_artifact"), "expected_output",
                         vector_shape, kExpectedOutputBlake3),
      .expected_post_state = parse_artifact(
          root.at("expected_post_state_artifact"), "expected_post_state",
          state_shape, kExpectedPostStateBlake3),
  };
  if (fixture.ordered_artifact_blake3 != kExpectedOrderedArtifactBlake3 ||
      ordered_artifact_blake3(fixture) != kExpectedOrderedArtifactBlake3) {
    throw std::runtime_error("ordered fixture artifact BLAKE3 mismatch");
  }
  return fixture;
}

inline Metrics compare_bits(std::span<const std::uint16_t> actual,
                            std::span<const std::uint16_t> expected) {
  if (actual.size() != expected.size() || actual.empty()) {
    throw std::invalid_argument(
        "comparison vectors must have equal nonzero lengths");
  }
  double actual_mean = 0.0;
  double expected_mean = 0.0;
  double squared_error = 0.0;
  double expected_energy = 0.0;
  double maximum_absolute_error = 0.0;
  std::size_t exact_bit_mismatch_count = 0;
  for (std::size_t index = 0; index < actual.size(); ++index) {
    const double actual_value = decode_bf16(actual[index]);
    const double expected_value = decode_bf16(expected[index]);
    if (!std::isfinite(actual_value) || !std::isfinite(expected_value)) {
      return Metrics{
          .pcc = std::numeric_limits<double>::quiet_NaN(),
          .nmse = std::numeric_limits<double>::quiet_NaN(),
          .maximum_absolute_error = std::numeric_limits<double>::quiet_NaN(),
          .exact_bit_mismatch_count = actual.size(),
          .finite = false,
      };
    }
    const double difference = actual_value - expected_value;
    squared_error += difference * difference;
    expected_energy += expected_value * expected_value;
    maximum_absolute_error =
        std::max(maximum_absolute_error, std::abs(difference));
    actual_mean += actual_value;
    expected_mean += expected_value;
    exact_bit_mismatch_count +=
        static_cast<std::size_t>(actual[index] != expected[index]);
  }
  actual_mean /= static_cast<double>(actual.size());
  expected_mean /= static_cast<double>(expected.size());

  double covariance = 0.0;
  double actual_variance = 0.0;
  double expected_variance = 0.0;
  for (std::size_t index = 0; index < actual.size(); ++index) {
    const double actual_delta = decode_bf16(actual[index]) - actual_mean;
    const double expected_delta = decode_bf16(expected[index]) - expected_mean;
    covariance += actual_delta * expected_delta;
    actual_variance += actual_delta * actual_delta;
    expected_variance += expected_delta * expected_delta;
  }
  const double pcc =
      covariance /
      (std::sqrt(actual_variance * expected_variance) + kPccDenominatorFloor);
  const double nmse = squared_error / (expected_energy + kNmseDenominatorFloor);
  const bool finite = std::isfinite(pcc) && std::isfinite(nmse) &&
                      std::isfinite(maximum_absolute_error);
  return Metrics{
      .pcc = pcc,
      .nmse = nmse,
      .maximum_absolute_error = maximum_absolute_error,
      .exact_bit_mismatch_count = exact_bit_mismatch_count,
      .finite = finite,
  };
}

inline bool metrics_pass(const Metrics &metrics) {
  return metrics.finite && metrics.nmse < kBoundaryNmseCeiling;
}

inline Comparison compare_result(std::span<const std::uint16_t> output,
                                 std::span<const std::uint16_t> post_state,
                                 const Fixture &fixture) {
  const Metrics output_metrics =
      compare_bits(output, fixture.expected_output.bits);
  const Metrics state_metrics =
      compare_bits(post_state, fixture.expected_post_state.bits);
  const bool passed =
      metrics_pass(output_metrics) && metrics_pass(state_metrics);
  return Comparison{
      .output = output_metrics,
      .post_state = state_metrics,
      .nmse_ceiling = kBoundaryNmseCeiling,
      .passed = passed,
  };
}

inline ArtifactEvidence artifact_evidence(std::string_view role,
                                          std::span<const std::uint16_t> bits) {
  const std::vector<std::uint8_t> bytes = encode_bf16_bytes(bits);
  return ArtifactEvidence{
      .role = std::string(role),
      .element_count = bits.size(),
      .byte_count = bytes.size(),
      .blake3 = blake3_hex(bytes),
  };
}

inline bool self_test(const Fixture &fixture) {
  const Comparison exact = compare_result(
      fixture.expected_output.bits, fixture.expected_post_state.bits, fixture);
  if (!exact.passed || exact.output.exact_bit_mismatch_count != 0 ||
      exact.post_state.exact_bit_mismatch_count != 0 ||
      exact.output.nmse != 0.0 || exact.post_state.nmse != 0.0) {
    return false;
  }

  Metrics threshold_below = exact.output;
  threshold_below.nmse = std::nextafter(kBoundaryNmseCeiling, 0.0);
  Metrics threshold_equality = exact.output;
  threshold_equality.nmse = kBoundaryNmseCeiling;
  Metrics threshold_above = exact.output;
  threshold_above.nmse = std::nextafter(
      kBoundaryNmseCeiling, std::numeric_limits<double>::infinity());
  if (!metrics_pass(threshold_below) || metrics_pass(threshold_equality) ||
      metrics_pass(threshold_above)) {
    return false;
  }

  std::vector<std::uint16_t> zero_output(kVectorElementCount, 0);
  std::vector<std::uint16_t> zero_state(kStateElementCount, 0);
  const Comparison rejected = compare_result(zero_output, zero_state, fixture);
  if (rejected.passed || !rejected.output.finite ||
      !rejected.post_state.finite) {
    return false;
  }

  std::vector<std::uint16_t> non_finite_output = fixture.expected_output.bits;
  non_finite_output.front() = kPositiveInfinityBf16;
  const Comparison non_finite = compare_result(
      non_finite_output, fixture.expected_post_state.bits, fixture);
  if (non_finite.passed || non_finite.output.finite) {
    return false;
  }

  try {
    const std::array<std::uint16_t, 1> short_vector = {0};
    static_cast<void>(compare_bits(short_vector, fixture.expected_output.bits));
    return false;
  } catch (const std::invalid_argument &) {
  }

  const ArtifactEvidence output =
      artifact_evidence(kObservedOutputRole, fixture.expected_output.bits);
  const ArtifactEvidence state = artifact_evidence(
      kObservedPostStateRole, fixture.expected_post_state.bits);
  if (output.byte_count != kVectorElementCount * kBf16Bytes ||
      output.blake3 != kExpectedOutputBlake3 ||
      state.byte_count != kStateElementCount * kBf16Bytes ||
      state.blake3 != kExpectedPostStateBlake3) {
    return false;
  }
  return true;
}

} // namespace ttwkv7::boundary_device
