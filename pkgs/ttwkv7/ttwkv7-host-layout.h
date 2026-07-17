#pragma once

#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <utility>
#include <vector>

namespace ttwkv7::host_layout {

constexpr std::uint32_t kTileWidth = 32;
constexpr std::uint32_t kTileHeight = 32;

struct Matrix {
  std::uint32_t rows;
  std::uint32_t columns;
  std::vector<float> values;
};

struct WriterLayout {
  std::uint32_t token_rows;
  std::uint32_t logical_rows;
  std::uint32_t padded_rows;
  std::uint32_t columns;
};

inline std::optional<std::size_t> checked_product(std::size_t left,
                                                  std::size_t right) {
  if (left != 0 && right > std::numeric_limits<std::size_t>::max() / left) {
    return std::nullopt;
  }
  return left * right;
}

inline std::optional<std::uint32_t> checked_u32_product(std::uint32_t left,
                                                        std::uint32_t right) {
  const std::uint64_t product =
      static_cast<std::uint64_t>(left) * static_cast<std::uint64_t>(right);
  if (product > std::numeric_limits<std::uint32_t>::max()) {
    return std::nullopt;
  }
  return static_cast<std::uint32_t>(product);
}

inline std::optional<std::uint32_t> checked_u32_sum(std::uint32_t left,
                                                    std::uint32_t right) {
  if (right > std::numeric_limits<std::uint32_t>::max() - left) {
    return std::nullopt;
  }
  return left + right;
}

inline std::optional<std::uint32_t> round_up_to_tile(std::uint32_t value,
                                                     std::uint32_t tile_size) {
  if (value == 0 || tile_size == 0) {
    return std::nullopt;
  }
  const std::uint32_t remainder = value % tile_size;
  if (remainder == 0) {
    return value;
  }
  return checked_u32_sum(value, tile_size - remainder);
}

template <typename Shape> inline bool shape_is_valid(const Shape &shape) {
  const auto expected_channels =
      checked_u32_product(shape.head_count, shape.head_size);
  return shape.head_size != 0 && shape.head_count != 0 &&
         shape.padded_head_count >= shape.head_count &&
         shape.padded_head_count % kTileHeight == 0 &&
         shape.head_size % kTileWidth == 0 && expected_channels &&
         shape.channel_count == *expected_channels;
}

template <typename Shape>
std::optional<std::vector<Matrix>>
build_padded_input_blocks(const std::vector<float> &input, const Shape &shape,
                          std::uint32_t token_count,
                          std::uint32_t sequence_count) {
  if (!shape_is_valid(shape) || token_count == 0 || sequence_count == 0) {
    return std::nullopt;
  }
  const auto sequence_tokens = checked_u32_product(sequence_count, token_count);
  if (!sequence_tokens) {
    return std::nullopt;
  }
  const auto logical_block_elements =
      checked_product(shape.head_count, shape.head_size);
  const auto padded_block_elements =
      checked_product(shape.padded_head_count, shape.head_size);
  if (!logical_block_elements || !padded_block_elements) {
    return std::nullopt;
  }
  const auto expected_elements =
      checked_product(*sequence_tokens, *logical_block_elements);
  if (!expected_elements || input.size() != *expected_elements) {
    return std::nullopt;
  }

  std::vector<Matrix> blocks;
  blocks.reserve(*sequence_tokens);
  for (std::uint32_t sequence = 0; sequence < sequence_count; ++sequence) {
    for (std::uint32_t token = 0; token < token_count; ++token) {
      Matrix block{
          .rows = shape.padded_head_count,
          .columns = shape.head_size,
          .values = std::vector<float>(*padded_block_elements, 0.0F),
      };
      const std::size_t block_index =
          static_cast<std::size_t>(sequence) * token_count + token;
      const std::size_t source_offset = block_index * *logical_block_elements;
      for (std::uint32_t head = 0; head < shape.head_count; ++head) {
        for (std::uint32_t dimension = 0; dimension < shape.head_size;
             ++dimension) {
          const std::size_t logical_index =
              static_cast<std::size_t>(head) * shape.head_size + dimension;
          block.values[logical_index] = input[source_offset + logical_index];
        }
      }
      blocks.push_back(std::move(block));
    }
  }
  return blocks;
}

template <typename Shape, typename Tilize>
std::optional<std::vector<float>>
build_native_input(const std::vector<float> &input, const Shape &shape,
                   std::uint32_t token_count, std::uint32_t sequence_count,
                   Tilize tilize) {
  const auto blocks =
      build_padded_input_blocks(input, shape, token_count, sequence_count);
  if (!blocks) {
    return std::nullopt;
  }
  const auto elements_per_block =
      checked_product(shape.padded_head_count, shape.head_size);
  const auto total_elements =
      elements_per_block ? checked_product(blocks->size(), *elements_per_block)
                         : std::nullopt;
  if (!elements_per_block || !total_elements) {
    return std::nullopt;
  }

  std::vector<float> tiled;
  tiled.reserve(*total_elements);
  for (const Matrix &block : *blocks) {
    std::vector<float> converted =
        tilize(block.values, block.rows, block.columns);
    if (converted.size() != block.values.size()) {
      return std::nullopt;
    }
    tiled.insert(tiled.end(), converted.begin(), converted.end());
  }
  return tiled;
}

template <typename Shape>
std::optional<Matrix>
build_state_upload_matrix(const std::vector<float> &state, const Shape &shape,
                          std::uint32_t sequence_count,
                          std::uint32_t padded_sequence_count) {
  if (!shape_is_valid(shape) || sequence_count == 0 ||
      padded_sequence_count < sequence_count ||
      padded_sequence_count % kTileHeight != 0) {
    return std::nullopt;
  }
  const auto state_row_size = checked_product(
      shape.channel_count, static_cast<std::size_t>(shape.head_size));
  const auto expected_elements =
      state_row_size ? checked_product(sequence_count, *state_row_size)
                     : std::nullopt;
  const auto padded_elements =
      state_row_size ? checked_product(padded_sequence_count, *state_row_size)
                     : std::nullopt;
  if (!state_row_size || !expected_elements || !padded_elements ||
      *state_row_size > std::numeric_limits<std::uint32_t>::max() ||
      *state_row_size % kTileWidth != 0 || state.size() != *expected_elements) {
    return std::nullopt;
  }

  Matrix matrix{
      .rows = padded_sequence_count,
      .columns = static_cast<std::uint32_t>(*state_row_size),
      .values = std::vector<float>(*padded_elements, 0.0F),
  };
  for (std::uint32_t sequence = 0; sequence < sequence_count; ++sequence) {
    const std::size_t offset = static_cast<std::size_t>(sequence) *
                               static_cast<std::size_t>(*state_row_size);
    for (std::size_t element = 0; element < *state_row_size; ++element) {
      matrix.values[offset + element] = state[offset + element];
    }
  }
  return matrix;
}

template <typename Shape>
std::optional<WriterLayout> derive_writer_layout(const Shape &shape,
                                                 std::uint32_t sequence_count,
                                                 std::uint32_t token_count) {
  if (!shape_is_valid(shape) || sequence_count == 0 || token_count == 0) {
    return std::nullopt;
  }
  const auto token_rows = checked_u32_product(sequence_count, token_count);
  const auto state_rows = checked_u32_product(sequence_count, shape.head_size);
  const auto logical_rows = token_rows && state_rows
                                ? checked_u32_sum(*token_rows, *state_rows)
                                : std::nullopt;
  const auto padded_rows = logical_rows
                               ? round_up_to_tile(*logical_rows, kTileHeight)
                               : std::nullopt;
  if (!token_rows || !state_rows || !logical_rows || !padded_rows ||
      shape.channel_count % kTileWidth != 0) {
    return std::nullopt;
  }
  return WriterLayout{
      .token_rows = *token_rows,
      .logical_rows = *logical_rows,
      .padded_rows = *padded_rows,
      .columns = shape.channel_count,
  };
}

template <typename Shape>
std::optional<std::size_t>
writer_output_index(const WriterLayout &layout, const Shape &shape,
                    std::uint32_t sequence, std::uint32_t token,
                    std::uint32_t head, std::uint32_t dimension,
                    std::uint32_t token_count) {
  if (token_count == 0 || !shape_is_valid(shape) ||
      sequence >= layout.token_rows / token_count || token >= token_count ||
      head >= shape.head_count || dimension >= shape.head_size) {
    return std::nullopt;
  }
  const std::uint32_t row = sequence * token_count + token;
  const std::uint32_t column = head * shape.head_size + dimension;
  return static_cast<std::size_t>(row) * layout.columns + column;
}

template <typename Shape>
std::optional<std::size_t>
writer_state_index(const WriterLayout &layout, const Shape &shape,
                   std::uint32_t sequence, std::uint32_t head,
                   std::uint32_t row, std::uint32_t column,
                   std::uint32_t sequence_count) {
  if (!shape_is_valid(shape) || sequence >= sequence_count ||
      head >= shape.head_count || row >= shape.head_size ||
      column >= shape.head_size) {
    return std::nullopt;
  }
  const std::uint32_t head_row = head * shape.head_size + row;
  const std::uint32_t destination_row = layout.token_rows +
                                        sequence * shape.head_size +
                                        head_row / shape.head_count;
  const std::uint32_t destination_column =
      (head_row % shape.head_count) * shape.head_size + column;
  if (destination_row >= layout.logical_rows ||
      destination_column >= layout.columns) {
    return std::nullopt;
  }
  return static_cast<std::size_t>(destination_row) * layout.columns +
         destination_column;
}

} // namespace ttwkv7::host_layout
