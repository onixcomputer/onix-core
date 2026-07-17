#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>

namespace ttwkv7::decode_abi {

constexpr std::uint32_t kTileWidth = 32;
constexpr std::uint32_t kMaximumTokenCount = 32;
constexpr std::uint32_t kDecodeInstancePack = 4;
constexpr std::uint32_t kDecodeReaderChunkCount = 1;
constexpr std::uint32_t kDecodeTokensPerChunk = 1;
constexpr std::uint32_t kDecodeInstancesPerGroup = 1;
constexpr std::size_t kInputCount = 6;
constexpr std::size_t kReaderArgumentCount = 18;
constexpr std::size_t kComputeArgumentCount = 8;
constexpr std::size_t kWriterArgumentCount = 12;

enum class ReaderArgument : std::size_t {
  HeadCount,
  TokenCount,
  TilesPerHeadDimension,
  HeadTileRows,
  SequenceCount,
  Input0,
  Input1,
  Input2,
  Input3,
  Input4,
  Input5,
  State,
  TokenCountCompatibility,
  SelectorUnused,
  ConstantsUnused,
  ChunkCount,
  InstanceStart,
  InstanceEnd,
};

enum class ComputeArgument : std::size_t {
  TilesPerHeadDimension,
  InstanceCount,
  TokenCount,
  HeadTileRows,
  ChunkCount,
  InstanceStart,
  InstanceEnd,
  InstancePack,
};

enum class WriterArgument : std::size_t {
  Output,
  InstanceStart,
  InstanceEnd,
  InstanceCount,
  ChunkCount,
  HeadCount,
  TilesPerHeadDimension,
  ChannelTileCount,
  TokenRows,
  RealTokenCount,
  TokensPerChunk,
  InstancesPerGroup,
};

constexpr std::size_t index(ReaderArgument argument) {
  return static_cast<std::size_t>(argument);
}

constexpr std::size_t index(ComputeArgument argument) {
  return static_cast<std::size_t>(argument);
}

constexpr std::size_t index(WriterArgument argument) {
  return static_cast<std::size_t>(argument);
}

static_assert(index(ReaderArgument::InstanceEnd) + 1 == kReaderArgumentCount);
static_assert(index(ComputeArgument::InstancePack) + 1 ==
              kComputeArgumentCount);
static_assert(index(WriterArgument::InstancesPerGroup) + 1 ==
              kWriterArgumentCount);

struct DecodeConfig {
  std::uint32_t head_count;
  std::uint32_t tiles_per_head_dimension;
  std::uint32_t head_tile_rows;
  std::uint32_t sequence_count;
  std::uint32_t token_count;
  std::uint32_t channel_tile_count;
};

struct DecodeAddresses {
  std::array<std::uint32_t, kInputCount> inputs;
  std::uint32_t state;
  std::uint32_t output;
};

struct DecodeRuntimeArguments {
  std::array<std::uint32_t, kReaderArgumentCount> reader{};
  std::array<std::uint32_t, kComputeArgumentCount> compute{};
  std::array<std::uint32_t, kWriterArgumentCount> writer{};
};

constexpr std::optional<std::uint32_t> checked_product(std::uint32_t left,
                                                       std::uint32_t right) {
  const std::uint64_t product =
      static_cast<std::uint64_t>(left) * static_cast<std::uint64_t>(right);
  if (product > std::numeric_limits<std::uint32_t>::max()) {
    return std::nullopt;
  }
  return static_cast<std::uint32_t>(product);
}

constexpr bool addresses_are_valid(const DecodeAddresses &addresses) {
  if (addresses.state == 0 || addresses.output == 0) {
    return false;
  }
  for (const std::uint32_t address : addresses.inputs) {
    if (address == 0) {
      return false;
    }
  }
  return true;
}

constexpr std::optional<DecodeRuntimeArguments> make_decode_runtime_arguments(
    const DecodeConfig &config, const DecodeAddresses &addresses,
    std::uint32_t instance_start, std::uint32_t instance_end) {
  if (config.head_count == 0 || config.tiles_per_head_dimension == 0 ||
      config.head_tile_rows == 0 || config.sequence_count == 0 ||
      config.token_count == 0 || config.token_count > kMaximumTokenCount ||
      config.channel_tile_count == 0 || !addresses_are_valid(addresses)) {
    return std::nullopt;
  }

  const auto expected_head_tile_rows =
      checked_product(config.head_tile_rows, kTileWidth);
  const auto instance_count =
      checked_product(config.sequence_count, config.head_count);
  const auto expected_channel_tiles =
      checked_product(config.head_count, config.tiles_per_head_dimension);
  const auto token_rows =
      checked_product(config.sequence_count, config.token_count);
  if (!expected_head_tile_rows ||
      *expected_head_tile_rows < config.head_count ||
      *expected_head_tile_rows - config.head_count >= kTileWidth ||
      !instance_count || !expected_channel_tiles ||
      config.channel_tile_count != *expected_channel_tiles || !token_rows ||
      instance_start >= instance_end || instance_end > *instance_count) {
    return std::nullopt;
  }

  DecodeRuntimeArguments arguments;
  arguments.reader[index(ReaderArgument::HeadCount)] = config.head_count;
  arguments.reader[index(ReaderArgument::TokenCount)] = config.token_count;
  arguments.reader[index(ReaderArgument::TilesPerHeadDimension)] =
      config.tiles_per_head_dimension;
  arguments.reader[index(ReaderArgument::HeadTileRows)] = config.head_tile_rows;
  arguments.reader[index(ReaderArgument::SequenceCount)] =
      config.sequence_count;
  for (std::size_t input = 0; input < addresses.inputs.size(); ++input) {
    arguments.reader[index(ReaderArgument::Input0) + input] =
        addresses.inputs[input];
  }
  arguments.reader[index(ReaderArgument::State)] = addresses.state;
  arguments.reader[index(ReaderArgument::TokenCountCompatibility)] =
      config.token_count;
  arguments.reader[index(ReaderArgument::SelectorUnused)] = 0;
  arguments.reader[index(ReaderArgument::ConstantsUnused)] = 0;
  arguments.reader[index(ReaderArgument::ChunkCount)] = kDecodeReaderChunkCount;
  arguments.reader[index(ReaderArgument::InstanceStart)] = instance_start;
  arguments.reader[index(ReaderArgument::InstanceEnd)] = instance_end;

  arguments.compute[index(ComputeArgument::TilesPerHeadDimension)] =
      config.tiles_per_head_dimension;
  arguments.compute[index(ComputeArgument::InstanceCount)] = *instance_count;
  arguments.compute[index(ComputeArgument::TokenCount)] = config.token_count;
  arguments.compute[index(ComputeArgument::HeadTileRows)] =
      config.head_tile_rows;
  arguments.compute[index(ComputeArgument::ChunkCount)] =
      kDecodeReaderChunkCount;
  arguments.compute[index(ComputeArgument::InstanceStart)] = instance_start;
  arguments.compute[index(ComputeArgument::InstanceEnd)] = instance_end;
  arguments.compute[index(ComputeArgument::InstancePack)] = kDecodeInstancePack;

  arguments.writer[index(WriterArgument::Output)] = addresses.output;
  arguments.writer[index(WriterArgument::InstanceStart)] = instance_start;
  arguments.writer[index(WriterArgument::InstanceEnd)] = instance_end;
  arguments.writer[index(WriterArgument::InstanceCount)] = *instance_count;
  arguments.writer[index(WriterArgument::ChunkCount)] = config.token_count;
  arguments.writer[index(WriterArgument::HeadCount)] = config.head_count;
  arguments.writer[index(WriterArgument::TilesPerHeadDimension)] =
      config.tiles_per_head_dimension;
  arguments.writer[index(WriterArgument::ChannelTileCount)] =
      config.channel_tile_count;
  arguments.writer[index(WriterArgument::TokenRows)] = *token_rows;
  arguments.writer[index(WriterArgument::RealTokenCount)] = config.token_count;
  arguments.writer[index(WriterArgument::TokensPerChunk)] =
      kDecodeTokensPerChunk;
  arguments.writer[index(WriterArgument::InstancesPerGroup)] =
      kDecodeInstancesPerGroup;
  return arguments;
}

} // namespace ttwkv7::decode_abi
