#pragma once

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <set>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include <blake3.h>

#include "ttwkv7-boundary-device.h"

namespace ttwkv7::dispatch_transport {

constexpr std::uint32_t kSchemaVersion = 1;
constexpr std::size_t kMagicWidth = 8;
constexpr std::array<std::uint8_t, kMagicWidth> kRequestMagic = {
    'R', 'K', 'W', '7', 'R', 'E', 'Q', '1'};
constexpr std::array<std::uint8_t, kMagicWidth> kResponseMagic = {
    'R', 'K', 'W', '7', 'R', 'S', 'P', '1'};
constexpr std::size_t kSequenceIdWidth = 32;
constexpr std::size_t kRequestIdWidth = 32;
constexpr std::size_t kInputRoleCount = 6;
constexpr std::size_t kFrameOrdinalCount = 3;
constexpr std::size_t kFrameDimensionCount = 3;
constexpr std::size_t kU32Width = 4;
constexpr std::size_t kBf16Width = 2;
constexpr std::size_t kHeadCount = boundary_device::kHeadCount;
constexpr std::size_t kHeadSize = boundary_device::kHeadSize;
constexpr std::size_t kHiddenSize = boundary_device::kHiddenSize;
constexpr std::size_t kStateElementCount = boundary_device::kStateElementCount;
constexpr std::size_t kLayerCount = 12;
constexpr std::size_t kTokenCount = 2;
constexpr std::size_t kFirstTokenIndex = 2;
constexpr std::size_t kExpectedCallCount = kLayerCount * kTokenCount;
constexpr std::size_t kExpectedContinuityCount = kLayerCount;
constexpr std::size_t kFrameMetadataWidth =
    (kFrameOrdinalCount + kFrameDimensionCount) * kU32Width;
constexpr std::size_t kFramePrefixWidth =
    kMagicWidth + kU32Width + kSequenceIdWidth + kFrameMetadataWidth;
constexpr std::size_t kRequestFrameByteCount =
    kFramePrefixWidth +
    (kInputRoleCount * kHiddenSize + kStateElementCount) * kBf16Width;
constexpr std::size_t kResponseFrameByteCount =
    kFramePrefixWidth + kRequestIdWidth +
    (kHiddenSize + kStateElementCount) * kBf16Width;
constexpr std::size_t kCallOrdinalOffset =
    kMagicWidth + kU32Width + kSequenceIdWidth;
constexpr std::size_t kTokenOrdinalOffset = kCallOrdinalOffset + kU32Width;
constexpr std::size_t kLayerOrdinalOffset = kTokenOrdinalOffset + kU32Width;
constexpr std::size_t kHeadCountOffset = kLayerOrdinalOffset + kU32Width;
constexpr std::size_t kHeadSizeOffset = kHeadCountOffset + kU32Width;
constexpr std::size_t kHiddenSizeOffset = kHeadSizeOffset + kU32Width;
constexpr std::size_t kRequestPayloadOffset = kFramePrefixWidth;
constexpr std::size_t kRequestStateOffset =
    kRequestPayloadOffset + kInputRoleCount * kHiddenSize * kBf16Width;
constexpr std::size_t kResponseRequestIdOffset = kFramePrefixWidth;
constexpr std::size_t kResponseOutputOffset =
    kResponseRequestIdOffset + kRequestIdWidth;
constexpr std::size_t kResponseStateOffset =
    kResponseOutputOffset + kHiddenSize * kBf16Width;
constexpr std::uint16_t kPositiveInfinityBf16 = 0x7f80;
constexpr std::uint32_t kBitsPerByte = 8;
constexpr std::string_view kTranscriptDomain =
    "rwkv-ttwkv7-dispatch-abi-transcript-v1";

static_assert(kRequestFrameByteCount == 107588);
static_assert(kResponseFrameByteCount == 99940);
static_assert(kRequestStateOffset + kStateElementCount * kBf16Width ==
              kRequestFrameByteCount);
static_assert(kResponseStateOffset + kStateElementCount * kBf16Width ==
              kResponseFrameByteCount);

struct RequestFrame {
  std::array<std::uint8_t, kSequenceIdWidth> sequence_id{};
  std::uint32_t call_ordinal = 0;
  std::uint32_t token_ordinal = 0;
  std::uint32_t layer_ordinal = 0;
  std::array<std::vector<std::uint16_t>, kInputRoleCount> input_bits;
  std::vector<std::uint16_t> pre_state_bits;
};

struct ResponsePayload {
  std::vector<std::uint16_t> raw_output_bits;
  std::vector<std::uint16_t> post_state_bits;
};

struct SessionSummary {
  std::size_t call_count;
  std::size_t same_layer_state_continuity_count;
  std::size_t request_frame_byte_count;
  std::size_t response_frame_byte_count;
  std::vector<std::string> ordered_request_blake3;
  std::vector<std::string> ordered_response_blake3;
  std::string transcript_blake3;
};

inline std::uint32_t decode_u32(std::span<const std::uint8_t> bytes,
                                std::size_t offset, std::string_view name) {
  if (offset > bytes.size() || bytes.size() - offset < kU32Width) {
    throw std::runtime_error(std::string(name) + " is truncated");
  }
  std::uint32_t value = 0;
  for (std::size_t byte = 0; byte < kU32Width; ++byte) {
    value |= static_cast<std::uint32_t>(bytes[offset + byte])
             << (byte * kBitsPerByte);
  }
  return value;
}

inline std::uint16_t decode_u16(std::span<const std::uint8_t> bytes,
                                std::size_t offset, std::string_view name) {
  if (offset > bytes.size() || bytes.size() - offset < kBf16Width) {
    throw std::runtime_error(std::string(name) + " is truncated");
  }
  return static_cast<std::uint16_t>(bytes[offset]) |
         (static_cast<std::uint16_t>(bytes[offset + 1]) << kBitsPerByte);
}

inline void append_u32(std::vector<std::uint8_t> &bytes, std::uint32_t value) {
  for (std::size_t byte = 0; byte < kU32Width; ++byte) {
    bytes.push_back(static_cast<std::uint8_t>(value >> (byte * kBitsPerByte)));
  }
}

inline void append_u16(std::vector<std::uint8_t> &bytes, std::uint16_t value) {
  bytes.push_back(static_cast<std::uint8_t>(value));
  bytes.push_back(static_cast<std::uint8_t>(value >> kBitsPerByte));
}

inline void append_u64_to_hasher(blake3_hasher &hasher, std::uint64_t value) {
  std::array<std::uint8_t, sizeof(value)> bytes{};
  for (std::size_t byte = 0; byte < bytes.size(); ++byte) {
    bytes[byte] = static_cast<std::uint8_t>(value >> (byte * kBitsPerByte));
  }
  blake3_hasher_update(&hasher, bytes.data(), bytes.size());
}

inline void require_finite_bits(std::span<const std::uint16_t> bits,
                                std::string_view name) {
  for (const std::uint16_t value : bits) {
    if (!std::isfinite(boundary_device::decode_bf16(value))) {
      throw std::runtime_error(std::string(name) +
                               " contains non-finite BF16 data");
    }
  }
}

inline std::vector<std::uint16_t>
decode_bits(std::span<const std::uint8_t> bytes, std::size_t offset,
            std::size_t count, std::string_view name) {
  if (count > (std::numeric_limits<std::size_t>::max() - offset) / kBf16Width) {
    throw std::runtime_error(std::string(name) + " byte count overflows");
  }
  const std::size_t end = offset + count * kBf16Width;
  if (end > bytes.size()) {
    throw std::runtime_error(std::string(name) + " is truncated");
  }
  std::vector<std::uint16_t> result;
  result.reserve(count);
  for (std::size_t index = 0; index < count; ++index) {
    result.push_back(decode_u16(bytes, offset + index * kBf16Width, name));
  }
  require_finite_bits(result, name);
  return result;
}

inline RequestFrame parse_request_frame(std::span<const std::uint8_t> bytes) {
  if (bytes.size() != kRequestFrameByteCount) {
    throw std::runtime_error("dispatch request frame byte count mismatch");
  }
  if (!std::equal(kRequestMagic.begin(), kRequestMagic.end(), bytes.begin())) {
    throw std::runtime_error("dispatch request magic mismatch");
  }
  if (decode_u32(bytes, kMagicWidth, "dispatch schema") != kSchemaVersion) {
    throw std::runtime_error("dispatch request schema mismatch");
  }
  RequestFrame request;
  std::copy_n(bytes.begin() + kMagicWidth + kU32Width,
              request.sequence_id.size(), request.sequence_id.begin());
  request.call_ordinal =
      decode_u32(bytes, kCallOrdinalOffset, "dispatch call ordinal");
  request.token_ordinal =
      decode_u32(bytes, kTokenOrdinalOffset, "dispatch token ordinal");
  request.layer_ordinal =
      decode_u32(bytes, kLayerOrdinalOffset, "dispatch layer ordinal");
  if (decode_u32(bytes, kHeadCountOffset, "dispatch head count") !=
          kHeadCount ||
      decode_u32(bytes, kHeadSizeOffset, "dispatch head size") != kHeadSize ||
      decode_u32(bytes, kHiddenSizeOffset, "dispatch hidden size") !=
          kHiddenSize) {
    throw std::runtime_error("dispatch request dimensions changed");
  }
  std::size_t offset = kRequestPayloadOffset;
  for (std::size_t role = 0; role < kInputRoleCount; ++role) {
    request.input_bits[role] =
        decode_bits(bytes, offset, kHiddenSize, "dispatch request input");
    offset += kHiddenSize * kBf16Width;
  }
  request.pre_state_bits = decode_bits(bytes, offset, kStateElementCount,
                                       "dispatch request pre-state");
  return request;
}

inline std::vector<std::uint8_t>
encode_response_frame(const RequestFrame &request,
                      std::span<const std::uint8_t> request_bytes,
                      const ResponsePayload &payload) {
  if (request_bytes.size() != kRequestFrameByteCount ||
      payload.raw_output_bits.size() != kHiddenSize ||
      payload.post_state_bits.size() != kStateElementCount) {
    throw std::runtime_error("dispatch response shape contract changed");
  }
  require_finite_bits(payload.raw_output_bits, "dispatch response output");
  require_finite_bits(payload.post_state_bits, "dispatch response state");
  std::vector<std::uint8_t> response;
  response.reserve(kResponseFrameByteCount);
  response.insert(response.end(), kResponseMagic.begin(), kResponseMagic.end());
  append_u32(response, kSchemaVersion);
  response.insert(response.end(), request.sequence_id.begin(),
                  request.sequence_id.end());
  append_u32(response, request.call_ordinal);
  append_u32(response, request.token_ordinal);
  append_u32(response, request.layer_ordinal);
  append_u32(response, kHeadCount);
  append_u32(response, kHeadSize);
  append_u32(response, kHiddenSize);
  const std::string request_hash =
      boundary_device::blake3_hex(request_bytes.data(), request_bytes.size());
  const std::vector<std::uint8_t> request_hash_bytes =
      boundary_device::decode_lowercase_hex(request_hash, "request BLAKE3");
  response.insert(response.end(), request_hash_bytes.begin(),
                  request_hash_bytes.end());
  for (const std::uint16_t value : payload.raw_output_bits) {
    append_u16(response, value);
  }
  for (const std::uint16_t value : payload.post_state_bits) {
    append_u16(response, value);
  }
  if (response.size() != kResponseFrameByteCount) {
    throw std::logic_error("dispatch response frame size changed");
  }
  return response;
}

inline std::vector<float> decode_values(std::span<const std::uint16_t> bits,
                                        std::string_view name) {
  return boundary_device::decode_bf16_values(bits, name);
}

inline boundary_device::Artifact
artifact_from_bits(std::string name, std::vector<std::uint32_t> shape,
                   std::span<const std::uint16_t> bits) {
  std::vector<std::uint16_t> owned_bits(bits.begin(), bits.end());
  std::vector<std::uint8_t> bytes = boundary_device::encode_bf16_bytes(bits);
  std::vector<float> values = decode_values(bits, name);
  return boundary_device::Artifact{
      .name = std::move(name),
      .logical_shape = std::move(shape),
      .bytes = bytes,
      .bits = std::move(owned_bits),
      .values = std::move(values),
      .blake3 = boundary_device::blake3_hex(bytes),
  };
}

inline boundary_device::Fixture
invocation_fixture(const RequestFrame &request) {
  const std::vector<std::uint32_t> vector_shape = {
      static_cast<std::uint32_t>(kHeadCount),
      static_cast<std::uint32_t>(kHeadSize)};
  const std::vector<std::uint32_t> state_shape = {
      static_cast<std::uint32_t>(kHeadCount),
      static_cast<std::uint32_t>(kHeadSize),
      static_cast<std::uint32_t>(kHeadSize)};
  boundary_device::Fixture fixture;
  constexpr std::array<std::string_view, kInputRoleCount> names = {
      "a", "w", "k", "v", "r", "b"};
  for (std::size_t role = 0; role < kInputRoleCount; ++role) {
    fixture.inputs[role] = artifact_from_bits(
        std::string(names[role]), vector_shape, request.input_bits[role]);
  }
  fixture.pre_state =
      artifact_from_bits("pre_state", state_shape, request.pre_state_bits);
  return fixture;
}

class DispatchSessionCore {
public:
  DispatchSessionCore() {
    blake3_hasher_init(&transcript_);
    blake3_hasher_update(&transcript_, kTranscriptDomain.data(),
                         kTranscriptDomain.size());
  }

  RequestFrame accept_request(std::span<const std::uint8_t> bytes) {
    if (closed_) {
      throw std::runtime_error("dispatch session is already closed");
    }
    if (next_call_ >= kExpectedCallCount) {
      throw std::runtime_error("dispatch session received an extra request");
    }
    RequestFrame request = parse_request_frame(bytes);
    const std::size_t expected_token =
        kFirstTokenIndex + next_call_ / kLayerCount;
    const std::size_t expected_layer = next_call_ % kLayerCount;
    if (request.call_ordinal != next_call_ ||
        request.token_ordinal != expected_token ||
        request.layer_ordinal != expected_layer) {
      throw std::runtime_error("dispatch request authority order mismatch");
    }
    if (!sequence_id_) {
      sequence_id_ = request.sequence_id;
    } else if (*sequence_id_ != request.sequence_id) {
      throw std::runtime_error("dispatch sequence identity changed");
    }
    if (last_post_states_[expected_layer]) {
      if (*last_post_states_[expected_layer] != request.pre_state_bits) {
        throw std::runtime_error(
            "dispatch same-layer physical state continuity mismatch");
      }
      ++continuity_count_;
    }
    return request;
  }

  std::vector<std::uint8_t>
  record_response(const RequestFrame &request,
                  std::span<const std::uint8_t> request_bytes,
                  const ResponsePayload &payload) {
    if (next_call_ >= kExpectedCallCount ||
        request.call_ordinal != next_call_) {
      throw std::runtime_error("dispatch response has no matching request");
    }
    std::vector<std::uint8_t> response =
        encode_response_frame(request, request_bytes, payload);
    const std::string request_hash =
        boundary_device::blake3_hex(request_bytes.data(), request_bytes.size());
    const std::string response_hash =
        boundary_device::blake3_hex(response.data(), response.size());
    ordered_request_blake3_.push_back(request_hash);
    ordered_response_blake3_.push_back(response_hash);
    append_u64_to_hasher(transcript_, request_bytes.size());
    blake3_hasher_update(&transcript_, request_bytes.data(),
                         request_bytes.size());
    append_u64_to_hasher(transcript_, response.size());
    blake3_hasher_update(&transcript_, response.data(), response.size());
    const std::size_t layer = next_call_ % kLayerCount;
    last_post_states_[layer] = payload.post_state_bits;
    ++next_call_;
    return response;
  }

  SessionSummary finish() {
    if (closed_) {
      throw std::runtime_error("dispatch session was closed twice");
    }
    if (next_call_ != kExpectedCallCount ||
        continuity_count_ != kExpectedContinuityCount) {
      throw std::runtime_error("dispatch session is incomplete");
    }
    const std::set<std::string> unique_requests(ordered_request_blake3_.begin(),
                                                ordered_request_blake3_.end());
    const std::set<std::string> unique_responses(
        ordered_response_blake3_.begin(), ordered_response_blake3_.end());
    if (unique_requests.size() != kExpectedCallCount ||
        unique_responses.size() != kExpectedCallCount) {
      throw std::runtime_error("dispatch session contains duplicate frames");
    }
    closed_ = true;
    return SessionSummary{
        .call_count = next_call_,
        .same_layer_state_continuity_count = continuity_count_,
        .request_frame_byte_count = kRequestFrameByteCount,
        .response_frame_byte_count = kResponseFrameByteCount,
        .ordered_request_blake3 = ordered_request_blake3_,
        .ordered_response_blake3 = ordered_response_blake3_,
        .transcript_blake3 = boundary_device::finalize_blake3(transcript_),
    };
  }

private:
  std::optional<std::array<std::uint8_t, kSequenceIdWidth>> sequence_id_;
  std::array<std::optional<std::vector<std::uint16_t>>, kLayerCount>
      last_post_states_{};
  std::size_t next_call_ = 0;
  std::size_t continuity_count_ = 0;
  bool closed_ = false;
  std::vector<std::string> ordered_request_blake3_;
  std::vector<std::string> ordered_response_blake3_;
  blake3_hasher transcript_{};
};

inline std::vector<std::uint8_t> self_test_request(
    std::size_t call,
    const std::array<std::vector<std::uint16_t>, kLayerCount> &states) {
  const std::size_t token = kFirstTokenIndex + call / kLayerCount;
  const std::size_t layer = call % kLayerCount;
  std::vector<std::uint8_t> request;
  request.reserve(kRequestFrameByteCount);
  request.insert(request.end(), kRequestMagic.begin(), kRequestMagic.end());
  append_u32(request, kSchemaVersion);
  for (std::size_t index = 0; index < kSequenceIdWidth; ++index) {
    request.push_back(static_cast<std::uint8_t>(index + 1));
  }
  append_u32(request, static_cast<std::uint32_t>(call));
  append_u32(request, static_cast<std::uint32_t>(token));
  append_u32(request, static_cast<std::uint32_t>(layer));
  append_u32(request, kHeadCount);
  append_u32(request, kHeadSize);
  append_u32(request, kHiddenSize);
  for (std::size_t role = 0; role < kInputRoleCount; ++role) {
    const std::uint16_t bits = static_cast<std::uint16_t>(0x3f00 + role);
    for (std::size_t element = 0; element < kHiddenSize; ++element) {
      append_u16(request, bits);
    }
  }
  for (const std::uint16_t bits : states[layer]) {
    append_u16(request, bits);
  }
  if (request.size() != kRequestFrameByteCount) {
    throw std::logic_error("dispatch self-test request size changed");
  }
  return request;
}

inline bool self_test() {
  std::array<std::vector<std::uint16_t>, kLayerCount> states;
  for (std::size_t layer = 0; layer < kLayerCount; ++layer) {
    states[layer] = std::vector<std::uint16_t>(kStateElementCount, 0);
  }
  DispatchSessionCore session;
  for (std::size_t call = 0; call < kExpectedCallCount; ++call) {
    std::vector<std::uint8_t> request_bytes = self_test_request(call, states);
    const RequestFrame request = session.accept_request(request_bytes);
    ResponsePayload payload{
        .raw_output_bits = std::vector<std::uint16_t>(kHiddenSize, 0x3f00),
        .post_state_bits = std::vector<std::uint16_t>(
            kStateElementCount, static_cast<std::uint16_t>(0x3f00 + call)),
    };
    states[call % kLayerCount] = payload.post_state_bits;
    const std::vector<std::uint8_t> response =
        session.record_response(request, request_bytes, payload);
    if (response.size() != kResponseFrameByteCount) {
      return false;
    }
  }
  const SessionSummary summary = session.finish();
  if (summary.call_count != kExpectedCallCount ||
      summary.same_layer_state_continuity_count != kExpectedContinuityCount ||
      summary.ordered_request_blake3.size() != kExpectedCallCount ||
      summary.ordered_response_blake3.size() != kExpectedCallCount) {
    return false;
  }

  auto expect_rejected = [](const std::vector<std::uint8_t> &bytes) {
    try {
      DispatchSessionCore negative;
      (void)negative.accept_request(bytes);
      return false;
    } catch (const std::exception &) {
      return true;
    }
  };
  std::array<std::vector<std::uint16_t>, kLayerCount> zero_states;
  for (auto &state : zero_states) {
    state = std::vector<std::uint16_t>(kStateElementCount, 0);
  }
  const std::vector<std::uint8_t> first = self_test_request(0, zero_states);
  std::vector<std::uint8_t> truncated(first.begin(), first.end() - 1);
  std::vector<std::uint8_t> bad_magic = first;
  bad_magic[0] ^= 1;
  std::vector<std::uint8_t> bad_schema = first;
  bad_schema[kMagicWidth] = static_cast<std::uint8_t>(kSchemaVersion + 1);
  std::vector<std::uint8_t> wrong_order = first;
  wrong_order[kLayerOrdinalOffset] = 1;
  std::vector<std::uint8_t> trailing = first;
  trailing.push_back(0);
  std::vector<std::uint8_t> non_finite = first;
  non_finite[kRequestPayloadOffset] =
      static_cast<std::uint8_t>(kPositiveInfinityBf16);
  non_finite[kRequestPayloadOffset + 1] =
      static_cast<std::uint8_t>(kPositiveInfinityBf16 >> kBitsPerByte);
  if (!expect_rejected(truncated) || !expect_rejected(bad_magic) ||
      !expect_rejected(bad_schema) || !expect_rejected(wrong_order) ||
      !expect_rejected(trailing) || !expect_rejected(non_finite)) {
    return false;
  }
  try {
    DispatchSessionCore incomplete;
    (void)incomplete.finish();
    return false;
  } catch (const std::exception &) {
  }
  try {
    (void)session.accept_request(first);
    return false;
  } catch (const std::exception &) {
  }

  try {
    DispatchSessionCore duplicate_response;
    const RequestFrame duplicate_request =
        duplicate_response.accept_request(first);
    const ResponsePayload payload{
        .raw_output_bits = std::vector<std::uint16_t>(kHiddenSize, 0),
        .post_state_bits = std::vector<std::uint16_t>(kStateElementCount, 0),
    };
    (void)duplicate_response.record_response(duplicate_request, first, payload);
    (void)duplicate_response.record_response(duplicate_request, first, payload);
    return false;
  } catch (const std::exception &) {
  }

  try {
    DispatchSessionCore continuity;
    std::array<std::vector<std::uint16_t>, kLayerCount> carried = zero_states;
    for (std::size_t call = 0; call < kLayerCount; ++call) {
      const std::vector<std::uint8_t> request_bytes =
          self_test_request(call, carried);
      const RequestFrame request = continuity.accept_request(request_bytes);
      const ResponsePayload payload{
          .raw_output_bits = std::vector<std::uint16_t>(kHiddenSize, 0x3f00),
          .post_state_bits =
              std::vector<std::uint16_t>(kStateElementCount, 0x3f00),
      };
      carried[call] = payload.post_state_bits;
      (void)continuity.record_response(request, request_bytes, payload);
    }
    const std::vector<std::uint8_t> drifted =
        self_test_request(kLayerCount, zero_states);
    (void)continuity.accept_request(drifted);
    return false;
  } catch (const std::exception &) {
  }
  return true;
}

} // namespace ttwkv7::dispatch_transport
