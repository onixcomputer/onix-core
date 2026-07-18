mod dispatch_abi;
mod observed_layer;

pub use dispatch_abi::{
    Ttwkv7DispatchAbiReceipt, emulate_ttwkv7_dispatch_response_frame,
    run_ttwkv7_dispatch_abi_fixture, validate_ttwkv7_dispatch_response_frame,
};
pub use observed_layer::{
    PersistentPhysicalCallReceipt, PersistentPhysicalDispatchProgress,
    PersistentPhysicalDispatchRequest, PersistentPhysicalModelDriver,
    PersistentPhysicalVectorComparisonReceipt, Ttwkv7ObservedLayerEvidence,
    Ttwkv7ObservedLayerReplayReceipt, Ttwkv7ObservedModelCarryReceipt,
    Ttwkv7ObservedModelDispatchReceipt, Ttwkv7ObservedStateCarryReceipt,
    Ttwkv7PersistentObservedModelDispatchReceipt, Ttwkv7PersistentPhysicalCoreReceipt,
    begin_ttwkv7_persistent_physical_model_driver, run_ttwkv7_observed_layer_checkpoint,
    run_ttwkv7_observed_model_carry_checkpoint, run_ttwkv7_observed_model_dispatch_checkpoint,
    run_ttwkv7_observed_state_carry_checkpoint,
    run_ttwkv7_persistent_observed_model_dispatch_checkpoint,
};

use half::bf16;
use safetensors::{Dtype, SafeTensors, tensor::TensorView};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

pub const HIDDEN_SIZE: usize = 768;
pub const HEAD_SIZE: usize = 64;
pub const HEAD_COUNT: usize = HIDDEN_SIZE / HEAD_SIZE;
pub const INTERMEDIATE_SIZE: usize = 3072;
pub const DECAY_RANK: usize = 64;
pub const A_RANK: usize = 64;
pub const GATE_RANK: usize = 128;
pub const VALUE_RANK: usize = 32;
pub const MODEL_LAYER_COUNT: usize = 12;
pub const VOCABULARY_SIZE: usize = 65536;
pub const MODEL_CONFIG_BOS_TOKEN_ID: usize = 1;
pub const MODEL_CONFIG_EOS_TOKEN_ID: usize = 2;
pub const TOKENIZER_BOS_TOKEN_ID: usize = 0;
pub const BYTE_VOCABULARY_EOS_TOKEN_ID: usize = 261;
pub const TOKENIZER_WRAPPER_EOS_TOKEN_ID: usize = 65_530;
pub const GENERATION_CONFIG_BOS_TOKEN_ID: usize = 0;
pub const GENERATION_CONFIG_EOS_TOKEN_ID: usize = 0;
pub const RECEIPT_SCHEMA_VERSION: u32 = 1;
pub const DECODE_STEP_COUNT: usize = 3;
pub const TEXT_GENERATION_STEP_LIMIT: usize = 3;
pub const PROMPT_MAX_MESSAGE_BYTES: usize = 256;
pub const PROMPT_MAX_TOKEN_COUNT: usize = 32;
pub const PROMPT_MAX_NEW_TOKEN_COUNT: usize = 4;
pub const TTWKV7_BOUNDARY_INPUT_COUNT: usize = 6;
pub const TTWKV7_BOUNDARY_ARTIFACT_COUNT: usize = 9;
pub const MODEL_REVISION: &str = "d81965cb4e1a9f96696b4f70b84212b8f2e43216";
pub const MODEL_SHA256_SRI: &str = "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=";
pub const MODEL_BLAKE3: &str = "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5";
pub const MODEL_BYTE_COUNT: u64 = 382_111_072;
pub const ORACLE_TOLERANCE: f32 = 1.0e-5;
pub const REPLAY_TOLERANCE: f32 = 1.0e-5;
pub const STATE_CARRY_DIVERGENCE_FLOOR: f32 = 1.0e-4;
pub const TOKENIZER_VOCAB_SHA256_SRI: &str = "sha256-5t7j1OMbTVxArJlQisbHAc7vS+1oG/IWfOmpCFUryok=";
pub const TOKENIZER_CONFIG_SHA256_SRI: &str = "sha256-TgOqD11rGkAGoNnp8HDwFBjnNKsXx8SPKDM1lta9Xik=";
pub const ADDED_TOKENS_SHA256_SRI: &str = "sha256-o0nK5s2qaAz2/A0pKbFvKp7bQ+twJ7LjRLHKgGOFT7k=";
pub const TOKENIZER_IMPLEMENTATION_SHA256_SRI: &str =
    "sha256-qspeag9W0EPKFlTp3K+Qb888DgO1FyhjrXUGDoaFoQ4=";
pub const SPECIAL_TOKENS_MAP_SHA256_SRI: &str =
    "sha256-H1EppN7ADOM+XFzScmyVKyKkeCcyHu08UY1DXUpkYBU=";
pub const MODEL_CONFIG_SHA256_SRI: &str = "sha256-VcFZ/IlA4WVXpCsE8K7QN0TxdiIcwSY3aUqx9+EMTG8=";
pub const GENERATION_CONFIG_SHA256_SRI: &str =
    "sha256-2milZURvylpqKvSzCIkS6VOWX7+m6WgBmhTXVj1Y2Tc=";
pub const TOKENIZER_VOCAB_BLAKE3: &str =
    "3997a74891dd68ced8daadae0d7475274b08988c9263ca042896c8106967aef2";
pub const TOKENIZER_CONFIG_BLAKE3: &str =
    "b2411eb362aefa260493811c9414e8da589a19d6cec44e8456953507e293755e";
pub const ADDED_TOKENS_BLAKE3: &str =
    "02893c22a1e92502fdd31ba4d57b6e574692023505be7ba82d68d1e3142ff02f";
pub const TOKENIZER_IMPLEMENTATION_BLAKE3: &str =
    "0a2a88e97b455858e03bbbc83bb0228d8f36c2731fcb91cd94f05e2930e2aa24";
pub const SPECIAL_TOKENS_MAP_BLAKE3: &str =
    "751ae3ea4b59073218a85facbee1536739b0aa26d5d5670e11ef6815e5bac870";
pub const MODEL_CONFIG_BLAKE3: &str =
    "113edfd55813d327ae7e37987ee9c5ed123c69fa809670b3a0bcc07fd1e9295d";
pub const GENERATION_CONFIG_BLAKE3: &str =
    "2288838a56ea704a85691828bbc7f0ab2934c949b13a4d8f3af1b13d955ac2fa";
const LAYER_NORM_EPSILON: f32 = 1.0e-5;
const NORMALIZATION_FLOOR: f32 = 1.0e-12;
const NEGATIVE_INVERSE_SQRT_E: f32 = -0.606_530_67;
const BF16_BYTE_WIDTH: usize = 2;
const HEX_RADIX: u32 = 16;
const HEX_ALPHA_DIGIT_OFFSET: u32 = 10;
const OCTAL_RADIX: u32 = 8;
const PYTHON_BYTE_HEX_DIGITS: usize = 2;
const PYTHON_SHORT_UNICODE_HEX_DIGITS: usize = 4;
const PYTHON_LONG_UNICODE_HEX_DIGITS: usize = 8;
const PYTHON_MAX_OCTAL_DIGITS: usize = 3;
const UTF8_MAX_BYTES_PER_SCALAR: usize = 4;
const HEX_CHARACTERS_PER_BYTE: usize = 2;
const ASCII_ALERT_BYTE: u8 = 0x07;
const ASCII_BACKSPACE_BYTE: u8 = 0x08;
const ASCII_FORM_FEED_BYTE: u8 = 0x0c;
const ASCII_VERTICAL_TAB_BYTE: u8 = 0x0b;
const EXPECTED_DIGEST_HEX_LENGTH: usize = 64;
const LAYER_INDEX: usize = 0;
const TOKEN_COUNT: usize = 2;
const TOKENIZER_VOCAB_ENTRY_COUNT: usize = 65_529;
const TOKENIZER_FIRST_VOCAB_ID: usize = 1;
const TOKENIZER_LAST_VOCAB_ID: usize = 65_529;
const TOKENIZER_VOCAB_BYTE_COUNT: u64 = 1_093_733;
const TOKENIZER_SPECIAL_TEXT: &str = "<|rwkv_tokenizer_end_of_text|>";
const TOKENIZER_EOS_TEXT: &str = "\n\n";
const FIXED_USER_MESSAGE: &str = "Hi";
const FIXED_CHAT_PROMPT: &str = "User: Hi\n\nAssistant:";
const FIXED_RENDERED_CHAT_PROMPT: &str = "<|rwkv_tokenizer_end_of_text|>User: Hi\n\nAssistant:";
const PROMPT_MESSAGE_OPTION: &str = "--message";
const PROMPT_TOKEN_LIMIT_OPTION: &str = "--max-prompt-tokens";
const PROMPT_NEW_TOKEN_LIMIT_OPTION: &str = "--max-new-tokens";
const PROMPT_REQUIRED_OPTION_COUNT: usize = 3;
const PROMPT_OPTION_COMPONENT_COUNT: usize = 2;
const PROMPT_EXPECTED_ARGUMENT_COUNT: usize =
    PROMPT_REQUIRED_OPTION_COUNT * PROMPT_OPTION_COMPONENT_COUNT;
const TTWKV7_BOUNDARY_TARGET: &str = "ttwkv7_logical_wkv_boundary";
const TTWKV7_BOUNDARY_PRECISION: &str = "little_endian_bf16_storage_cpu_fp32_recurrence";
const TTWKV7_BOUNDARY_BYTE_ORDER: &str = "little_endian";
const TTWKV7_BOUNDARY_STATE_ORDER: &str = "head_row_column";
const TTWKV7_BOUNDARY_VECTOR_ORDER: &str = "head_dimension";
const TTWKV7_BOUNDARY_OUTPUT_ORDER: &str = "head_row";
const TTWKV7_BOUNDARY_HASH_DOMAIN: &[u8] = b"rwkv-ttwkv7-boundary-v1";
const TTWKV7_BOUNDARY_NONZERO_FLOOR: f32 = 1.0e-6;
const TTWKV7_BOUNDARY_INPUT_ORDER: [&str; TTWKV7_BOUNDARY_INPUT_COUNT] =
    ["a", "w", "k", "v", "r", "b"];
const TTWKV7_BOUNDARY_VECTOR_SHAPE: [usize; 2] = [HEAD_COUNT, HEAD_SIZE];
const TTWKV7_BOUNDARY_STATE_SHAPE: [usize; 3] = [HEAD_COUNT, HEAD_SIZE, HEAD_SIZE];
const TTWKV7_BOUNDARY_ARTIFACT_ORDER: [&str; TTWKV7_BOUNDARY_ARTIFACT_COUNT] = [
    "a",
    "w",
    "k",
    "v",
    "r",
    "b",
    "pre_state",
    "expected_output",
    "expected_post_state",
];
const REFERENCE_EMPTY_TOKEN_IDS: &[usize] = &[];
const REFERENCE_EOS_TOKEN_IDS: &[usize] = &[BYTE_VOCABULARY_EOS_TOKEN_ID];
const REFERENCE_OVERLAP_TOKEN_IDS: &[usize] = &[24_364];
const REFERENCE_ASCII_TOKEN_IDS: &[usize] = &[34_550];
const REFERENCE_UNICODE_TOKEN_IDS: &[usize] = &[1_413, 1_184, 5_044, 33, 10_267, 14_610];
const REFERENCE_CONTROL_TOKEN_IDS: &[usize] = &[1, 2, 256];
const REFERENCE_BYTE_PROMPT_TOKEN_IDS: &[usize] = &[24_281, 59, 3_880, 261, 5_585, 41_693, 59];
const REFERENCE_WRAPPER_PROMPT_TOKEN_IDS: &[usize] =
    &[0, 24_281, 59, 3_880, 65_530, 5_585, 41_693, 59];
const ARITHMETIC_PRECISION: &str = "cpu_fp32_from_bf16";
const MODEL_ID: &str = "RWKV/RWKV7-Goose-World2.8-0.1B-HF";
const NON_CLAIMS: [&str; 7] = [
    "No full-model logits are established.",
    "No generated token is established.",
    "No general RWKV correctness is established.",
    "No P150 numerical parity is established.",
    "No repaired-reader completion is established.",
    "No text generation is established.",
    "No throughput or latency claim is established.",
];
const TOKEN_NON_CLAIMS: [&str; 9] = [
    "No decoded text is established.",
    "The selected token is not executed as a recurrent third step.",
    "No sampling or multi-token generation is established.",
    "No FLA or official-runtime bit parity is established.",
    "No general RWKV correctness is established.",
    "No P150 numerical parity is established.",
    "No ttWKV7 integration or parity is established.",
    "No repaired-reader completion is established.",
    "No throughput or latency claim is established.",
];
const DECODE_NON_CLAIMS: [&str; 10] = [
    "No decoded text or tokenizer mapping is established.",
    "Continuing after model-config EOS ID 2 is diagnostic and is not generation-config stop behavior.",
    "The final selected token is not executed as a recurrent next step.",
    "No sampling or unbounded generation is established.",
    "No arbitrary prompt or long-context stability is established.",
    "No FLA or official-runtime bit parity is established.",
    "No general RWKV correctness is established.",
    "No P150 numerical parity is established.",
    "No ttWKV7 integration or repaired-reader completion is established.",
    "No throughput or latency claim is established.",
];
const TEXT_NON_CLAIMS: [&str; 9] = [
    "No sampling or arbitrary prompt interface is established.",
    "No long-context stability is established.",
    "No FLA or official-runtime numerical parity is established.",
    "No general RWKV correctness is established.",
    "No P150 numerical parity is established.",
    "No ttWKV7 integration or parity is established.",
    "No repaired-reader completion is established.",
    "No linguistic quality claim is established.",
    "No throughput or latency claim is established.",
];
const TTWKV7_BOUNDARY_NON_CLAIMS: [&str; 10] = [
    "No ttWKV7 kernel execution or numerical parity is established.",
    "No accelerator runtime initialization is established.",
    "No P150 numerical correctness is established.",
    "No repaired-reader completion is established.",
    "No full-layer BF16 parity is established.",
    "No full-model BF16 parity is established.",
    "No token generation through ttWKV7 is established.",
    "No tt-kernel or serving integration is established.",
    "No throughput or latency claim is established.",
    "No new hardware execution is authorized.",
];
const PROMPT_NON_CLAIMS: [&str; 11] = [
    "No sampling or unbounded generation is established.",
    "No prompt secrecy or prompt-safety property is established.",
    "No long-context stability beyond the reported package cap is established.",
    "No FLA kernel/runtime or Transformers generation parity is established.",
    "No official checkpoint-runtime numerical parity is established.",
    "No general RWKV correctness is established.",
    "No P150 numerical parity is established.",
    "No ttWKV7 integration or parity is established.",
    "No repaired-reader completion is established.",
    "No linguistic quality claim is established.",
    "No throughput or latency claim is established.",
];

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
pub struct Dimensions {
    pub hidden_size: usize,
    pub head_size: usize,
    pub head_count: usize,
    pub intermediate_size: usize,
}

impl Dimensions {
    pub const fn reviewed() -> Self {
        Self {
            hidden_size: HIDDEN_SIZE,
            head_size: HEAD_SIZE,
            head_count: HEAD_COUNT,
            intermediate_size: INTERMEDIATE_SIZE,
        }
    }

    fn validate(self) -> Result<(), String> {
        if self.hidden_size == 0 || self.head_size == 0 || self.intermediate_size == 0 {
            return Err("all layer dimensions must be positive".to_owned());
        }
        if !self.hidden_size.is_multiple_of(self.head_size) {
            return Err("hidden_size must be divisible by head_size".to_owned());
        }
        if self.head_count != self.hidden_size / self.head_size {
            return Err("head_count does not match hidden_size / head_size".to_owned());
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
struct Matrix {
    rows: usize,
    columns: usize,
    values: Vec<f32>,
}

impl Matrix {
    fn new(rows: usize, columns: usize, values: Vec<f32>) -> Result<Self, String> {
        let expected = rows
            .checked_mul(columns)
            .ok_or_else(|| "matrix element count overflows usize".to_owned())?;
        if values.len() != expected {
            return Err(format!(
                "matrix shape [{rows}, {columns}] requires {expected} values, found {}",
                values.len()
            ));
        }
        require_finite(&values, "matrix")?;
        Ok(Self {
            rows,
            columns,
            values,
        })
    }
}

#[derive(Clone, Debug)]
struct LayerWeights {
    layer_index: usize,
    dimensions: Dimensions,
    pre_norm_weight: Option<Vec<f32>>,
    pre_norm_bias: Option<Vec<f32>>,
    attn_norm_weight: Vec<f32>,
    attn_norm_bias: Vec<f32>,
    x_r: Vec<f32>,
    x_w: Vec<f32>,
    x_k: Vec<f32>,
    x_v: Vec<f32>,
    x_a: Vec<f32>,
    x_g: Vec<f32>,
    r_projection: Matrix,
    k_projection: Matrix,
    v_projection: Matrix,
    output_projection: Matrix,
    w_down: Matrix,
    w_up: Matrix,
    w_bias: Vec<f32>,
    a_down: Matrix,
    a_up: Matrix,
    a_bias: Vec<f32>,
    gate_down: Matrix,
    gate_up: Matrix,
    value_down: Option<Matrix>,
    value_up: Option<Matrix>,
    value_bias: Option<Vec<f32>>,
    k_k: Vec<f32>,
    k_a: Vec<f32>,
    r_k: Vec<f32>,
    group_norm_weight: Vec<f32>,
    group_norm_bias: Vec<f32>,
    ffn_norm_weight: Vec<f32>,
    ffn_norm_bias: Vec<f32>,
    ffn_x_k: Vec<f32>,
    ffn_key: Matrix,
    ffn_value: Matrix,
}

#[derive(Clone, Debug)]
struct LayerState {
    attention_previous: Vec<f32>,
    ffn_previous: Vec<f32>,
    matrix: Vec<f32>,
}

impl LayerState {
    fn zero(dimensions: Dimensions) -> Result<Self, String> {
        dimensions.validate()?;
        let matrix_elements = dimensions
            .head_count
            .checked_mul(dimensions.head_size)
            .and_then(|value| value.checked_mul(dimensions.head_size))
            .ok_or_else(|| "state element count overflows usize".to_owned())?;
        Ok(Self {
            attention_previous: vec![0.0; dimensions.hidden_size],
            ffn_previous: vec![0.0; dimensions.hidden_size],
            matrix: vec![0.0; matrix_elements],
        })
    }
}

#[derive(Clone, Debug)]
struct ModelExecutionState {
    layers: Vec<LayerState>,
    oracle_matrices: Vec<Vec<f32>>,
    maximum_state_deviations: [f32; MODEL_LAYER_COUNT],
    maximum_output_deviations: [f32; MODEL_LAYER_COUNT],
}

impl ModelExecutionState {
    fn zero(dimensions: Dimensions) -> Result<Self, String> {
        let layers = (0..MODEL_LAYER_COUNT)
            .map(|_| LayerState::zero(dimensions))
            .collect::<Result<Vec<_>, _>>()?;
        let oracle_matrices = layers
            .iter()
            .map(|state| state.matrix.clone())
            .collect::<Vec<_>>();
        Ok(Self {
            layers,
            oracle_matrices,
            maximum_state_deviations: [0.0_f32; MODEL_LAYER_COUNT],
            maximum_output_deviations: [0.0_f32; MODEL_LAYER_COUNT],
        })
    }

    fn validate(&self, dimensions: Dimensions) -> Result<(), String> {
        if self.layers.len() != MODEL_LAYER_COUNT || self.oracle_matrices.len() != MODEL_LAYER_COUNT
        {
            return Err(format!(
                "model state requires {MODEL_LAYER_COUNT} layer and oracle slots, found {} and {}",
                self.layers.len(),
                self.oracle_matrices.len()
            ));
        }
        let matrix_elements = dimensions
            .head_count
            .checked_mul(dimensions.head_size)
            .and_then(|value| value.checked_mul(dimensions.head_size))
            .ok_or_else(|| "state validation element count overflows usize".to_owned())?;
        for (layer_index, (layer, oracle)) in self
            .layers
            .iter()
            .zip(self.oracle_matrices.iter())
            .enumerate()
        {
            require_length(
                &layer.attention_previous,
                dimensions.hidden_size,
                &format!("layer {layer_index} attention state"),
            )?;
            require_length(
                &layer.ffn_previous,
                dimensions.hidden_size,
                &format!("layer {layer_index} channel state"),
            )?;
            require_length(
                &layer.matrix,
                matrix_elements,
                &format!("layer {layer_index} matrix state"),
            )?;
            require_length(
                oracle,
                matrix_elements,
                &format!("layer {layer_index} oracle state"),
            )?;
            require_finite(&layer.attention_previous, "attention state")?;
            require_finite(&layer.ffn_previous, "channel state")?;
            require_finite(&layer.matrix, "matrix state")?;
            require_finite(oracle, "oracle state")?;
        }
        require_finite(&self.maximum_state_deviations, "state deviations")?;
        require_finite(&self.maximum_output_deviations, "output deviations")?;
        Ok(())
    }

    fn flattened_attention_previous(&self) -> Vec<f32> {
        self.layers
            .iter()
            .flat_map(|state| state.attention_previous.iter().copied())
            .collect()
    }

    fn flattened_ffn_previous(&self) -> Vec<f32> {
        self.layers
            .iter()
            .flat_map(|state| state.ffn_previous.iter().copied())
            .collect()
    }

    fn flattened_matrices(&self) -> Vec<f32> {
        self.layers
            .iter()
            .flat_map(|state| state.matrix.iter().copied())
            .collect()
    }

    fn flattened_complete_state(&self) -> Vec<f32> {
        self.layers
            .iter()
            .flat_map(|state| {
                state
                    .attention_previous
                    .iter()
                    .chain(state.ffn_previous.iter())
                    .chain(state.matrix.iter())
                    .copied()
            })
            .collect()
    }
}

#[derive(Clone, Debug)]
struct WkvInputs {
    r: Vec<f32>,
    w: Vec<f32>,
    k: Vec<f32>,
    v: Vec<f32>,
    a: Vec<f32>,
    b: Vec<f32>,
}

#[derive(Clone, Debug)]
struct TimeMixPreparation {
    projected_value: Vec<f32>,
    wkv_inputs: WkvInputs,
    gate: Vec<f32>,
}

#[derive(Clone, Debug)]
struct TimeMixOutput {
    preparation: TimeMixPreparation,
    raw_wkv_output: Vec<f32>,
    wkv_output: Vec<f32>,
    oracle_output: Vec<f32>,
    matrix_state: Vec<f32>,
    oracle_state: Vec<f32>,
}

#[derive(Clone, Debug)]
struct LayerSuffixOutput {
    ffn_input: Vec<f32>,
    final_output: Vec<f32>,
}

#[derive(Clone, Copy, Debug)]
enum LayerZeroWkvMode<'a> {
    SourceFp32,
    Bf16Cpu,
    Observed {
        raw_output: &'a [f32],
        post_state: &'a [f32],
    },
}

#[derive(Clone, Debug)]
struct ModelTokenExecution {
    execution: ModelExecutionState,
    final_output: Vec<f32>,
    layer_outputs: Vec<Vec<f32>>,
    layer_zero_pre_state: Vec<f32>,
    layer_zero_raw_output: Vec<f32>,
    layer_zero_post_state: Vec<f32>,
}

#[derive(Clone, Debug)]
struct SequenceResult {
    final_output: Vec<f32>,
    final_state: Vec<f32>,
    final_attention_previous: Vec<f32>,
    final_ffn_previous: Vec<f32>,
    second_pre_state: Vec<f32>,
    second_preparation: TimeMixPreparation,
    second_residual: Vec<f32>,
    second_ffn_previous: Vec<f32>,
    second_raw_output: Vec<f32>,
    maximum_state_deviation: f32,
    maximum_output_deviation: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct NumericReceipt {
    pub element_count: usize,
    pub minimum: f32,
    pub maximum: f32,
    pub mean: f64,
    pub l2_norm: f64,
    pub finite: bool,
    pub blake3: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct WkvReceipt {
    pub r: NumericReceipt,
    pub w: NumericReceipt,
    pub k: NumericReceipt,
    pub v: NumericReceipt,
    pub a: NumericReceipt,
    pub b: NumericReceipt,
}

#[derive(Clone, Debug, Serialize)]
pub struct Bf16ArtifactReceipt {
    pub name: &'static str,
    pub logical_shape: Vec<usize>,
    pub element_count: usize,
    pub byte_count: usize,
    pub blake3: String,
    pub bytes_hex: String,
}

#[derive(Clone, Debug)]
struct EncodedBf16Artifact {
    receipt: Bf16ArtifactReceipt,
    bytes: Vec<u8>,
}

#[derive(Clone, Debug, Serialize)]
pub struct Ttwkv7BoundaryReceipt {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_index: usize,
    pub prefix_token_ids: [usize; TOKEN_COUNT],
    pub target: &'static str,
    pub arithmetic_precision: &'static str,
    pub byte_order: &'static str,
    pub vector_order: &'static str,
    pub state_order: &'static str,
    pub output_order: &'static str,
    pub input_order: [&'static str; TTWKV7_BOUNDARY_INPUT_COUNT],
    pub source_fp32_inputs: WkvReceipt,
    pub source_fp32_pre_state: NumericReceipt,
    pub source_fp32_raw_output: NumericReceipt,
    pub source_fp32_post_state: NumericReceipt,
    pub input_artifacts: Vec<Bf16ArtifactReceipt>,
    pub pre_state_artifact: Bf16ArtifactReceipt,
    pub expected_output_artifact: Bf16ArtifactReceipt,
    pub expected_post_state_artifact: Bf16ArtifactReceipt,
    pub ordered_artifact_blake3: String,
    pub maximum_input_quantization_deviation: f32,
    pub pre_state_quantization_deviation: f32,
    pub expected_output_vs_source_deviation: f32,
    pub expected_post_state_vs_source_deviation: f32,
    pub matrix_oracle_output_deviation: f32,
    pub matrix_oracle_state_deviation: f32,
    pub retained_pre_state_maximum_absolute_value: f32,
    pub oracle_tolerance: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug, Serialize)]
pub struct ModelReceipt {
    pub model_id: &'static str,
    pub revision: &'static str,
    pub sha256_sri: &'static str,
    pub blake3: String,
    pub byte_count: u64,
}

#[derive(Clone, Debug, Serialize)]
pub struct LayerReceipt {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_index: usize,
    pub token_ids: [usize; TOKEN_COUNT],
    pub arithmetic_precision: &'static str,
    pub second_token_wkv: WkvReceipt,
    pub final_state: NumericReceipt,
    pub final_layer_output: NumericReceipt,
    pub maximum_oracle_state_deviation: f32,
    pub maximum_oracle_output_deviation: f32,
    pub oracle_tolerance: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug, Serialize)]
pub struct LayerDeviationReceipt {
    pub layer_index: usize,
    pub maximum_state_deviation: f32,
    pub maximum_output_deviation: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct TokenReceipt {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_count: usize,
    pub prefix_token_ids: [usize; TOKEN_COUNT],
    pub generated_token_id: usize,
    pub generated_logit: f32,
    pub runner_up_token_id: usize,
    pub runner_up_logit: f32,
    pub greedy_margin: f32,
    pub arithmetic_precision: &'static str,
    pub final_hidden: NumericReceipt,
    pub logits: NumericReceipt,
    pub recurrent_states: NumericReceipt,
    pub layer_oracle_deviations: Vec<LayerDeviationReceipt>,
    pub maximum_oracle_state_deviation: f32,
    pub maximum_oracle_output_deviation: f32,
    pub head_oracle_logit_deviation: f32,
    pub oracle_tolerance: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug, Serialize)]
pub struct FrameworkVectorFixture {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_count: usize,
    pub prefix_token_ids: [usize; TOKEN_COUNT],
    pub arithmetic_precision: &'static str,
    pub final_hidden: Vec<f32>,
    pub logits: Vec<f32>,
    pub recurrent_states: Vec<f32>,
    pub generated_token_id: usize,
    pub generated_logit: f32,
    pub runner_up_token_id: usize,
    pub runner_up_logit: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct DecodeStepReceipt {
    pub step_index: usize,
    pub input_token_id: usize,
    pub generated_token_id: usize,
    pub generated_logit: f32,
    pub runner_up_token_id: usize,
    pub runner_up_logit: f32,
    pub greedy_margin: f32,
    pub model_config_eos_selected: bool,
    pub final_hidden: NumericReceipt,
    pub logits: NumericReceipt,
    pub recurrent_states: NumericReceipt,
    pub layer_oracle_deviations: Vec<LayerDeviationReceipt>,
    pub incremental_replay_hidden_deviation: f32,
    pub incremental_replay_logits_deviation: f32,
    pub incremental_replay_state_deviation: f32,
    pub retained_vs_reset_hidden_deviation: f32,
    pub head_oracle_logit_deviation: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct DecodeReceipt {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub dimensions: Dimensions,
    pub layer_count: usize,
    pub seed_token_id: usize,
    pub generated_step_count: usize,
    pub processed_input_ids: Vec<usize>,
    pub generated_token_ids: Vec<usize>,
    pub model_config_eos_token_id: usize,
    pub model_config_eos_observed_steps: Vec<usize>,
    pub continued_after_model_config_eos: bool,
    pub arithmetic_precision: &'static str,
    pub steps: Vec<DecodeStepReceipt>,
    pub final_recurrent_states: NumericReceipt,
    pub maximum_oracle_state_deviation: f32,
    pub maximum_oracle_output_deviation: f32,
    pub maximum_replay_hidden_deviation: f32,
    pub maximum_replay_logits_deviation: f32,
    pub maximum_replay_state_deviation: f32,
    pub minimum_retained_vs_reset_hidden_deviation: f32,
    pub oracle_tolerance: f32,
    pub replay_tolerance: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Copy)]
pub struct TokenizerAuthorityInputs<'a> {
    pub vocabulary: &'a [u8],
    pub tokenizer_config: &'a [u8],
    pub added_tokens: &'a [u8],
    pub tokenizer_implementation: &'a [u8],
    pub special_tokens_map: &'a [u8],
    pub model_config: &'a [u8],
    pub generation_config: &'a [u8],
}

#[derive(Clone, Debug, Serialize)]
pub struct AuthorityArtifactReceipt {
    pub name: &'static str,
    pub sha256_sri: &'static str,
    pub blake3: String,
    pub byte_count: u64,
}

#[derive(Clone, Debug, Serialize)]
pub struct TokenizerFixtureReceipt {
    pub name: &'static str,
    pub source_bytes_hex: String,
    pub token_ids: Vec<usize>,
    pub roundtrip_bytes_hex: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct TokenizerContractReceipt {
    pub revision: &'static str,
    pub vocabulary_entry_count: usize,
    pub vocabulary_first_id: usize,
    pub vocabulary_last_id: usize,
    pub model_config_bos_token_id: usize,
    pub model_config_eos_token_id: usize,
    pub tokenizer_bos_token_id: usize,
    pub byte_vocabulary_eos_token_id: usize,
    pub tokenizer_wrapper_eos_token_id: usize,
    pub generation_config_bos_token_id: usize,
    pub generation_config_eos_token_id: usize,
    pub reference_fixtures: Vec<TokenizerFixtureReceipt>,
    pub artifacts: Vec<AuthorityArtifactReceipt>,
}

#[derive(Clone, Debug, Serialize)]
pub struct TextGenerationStepReceipt {
    pub step_index: usize,
    pub generated_token_id: usize,
    pub generated_logit: f32,
    pub runner_up_token_id: usize,
    pub runner_up_logit: f32,
    pub greedy_margin: f32,
    pub generated_token_bytes_hex: String,
    pub generation_eos_selected: bool,
    pub post_token_final_hidden: Option<NumericReceipt>,
    pub post_token_recurrent_states: Option<NumericReceipt>,
    pub incremental_replay_hidden_deviation: Option<f32>,
    pub incremental_replay_state_deviation: Option<f32>,
    pub retained_vs_reset_hidden_deviation: Option<f32>,
    pub head_oracle_logit_deviation: f32,
}

#[derive(Clone, Debug, Serialize)]
pub struct TextReceipt {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub tokenizer: TokenizerContractReceipt,
    pub dimensions: Dimensions,
    pub fixed_user_message: &'static str,
    pub fixed_chat_prompt: &'static str,
    pub rendered_chat_prompt: &'static str,
    pub prompt_token_ids: Vec<usize>,
    pub prompt_token_ids_blake3: String,
    pub generation_step_limit: usize,
    pub generated_token_ids: Vec<usize>,
    pub generated_token_ids_blake3: String,
    pub generated_bytes_hex: String,
    pub generated_text: String,
    pub stop_reason: &'static str,
    pub arithmetic_precision: &'static str,
    pub steps: Vec<TextGenerationStepReceipt>,
    pub final_recurrent_states: NumericReceipt,
    pub maximum_oracle_state_deviation: f32,
    pub maximum_oracle_output_deviation: f32,
    pub maximum_replay_hidden_deviation: f32,
    pub maximum_replay_state_deviation: f32,
    pub minimum_retained_vs_reset_hidden_deviation: f32,
    pub oracle_tolerance: f32,
    pub replay_tolerance: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PromptRequest {
    pub user_message: String,
    pub max_prompt_tokens: usize,
    pub max_new_tokens: usize,
}

#[derive(Clone, Debug, Serialize)]
pub struct PromptRequestReceipt {
    pub user_message: String,
    pub user_message_byte_count: usize,
    pub user_message_blake3: String,
    pub max_prompt_tokens: usize,
    pub max_new_tokens: usize,
    pub package_max_message_bytes: usize,
    pub package_max_prompt_tokens: usize,
    pub package_max_new_tokens: usize,
}

#[derive(Clone, Debug, Serialize)]
pub struct PromptReceipt {
    pub schema_version: u32,
    pub model: ModelReceipt,
    pub tokenizer: TokenizerContractReceipt,
    pub dimensions: Dimensions,
    pub request: PromptRequestReceipt,
    pub rendered_chat_prompt: String,
    pub rendered_chat_prompt_byte_count: usize,
    pub rendered_chat_prompt_blake3: String,
    pub prompt_token_count: usize,
    pub prompt_token_ids: Vec<usize>,
    pub prompt_token_ids_blake3: String,
    pub generated_token_limit: usize,
    pub generated_token_ids: Vec<usize>,
    pub generated_token_ids_blake3: String,
    pub generated_bytes_hex: String,
    pub generated_utf8_complete: bool,
    pub generated_text: Option<String>,
    pub stop_reason: &'static str,
    pub arithmetic_precision: &'static str,
    pub steps: Vec<TextGenerationStepReceipt>,
    pub final_recurrent_states: NumericReceipt,
    pub maximum_oracle_state_deviation: f32,
    pub maximum_oracle_output_deviation: f32,
    pub maximum_replay_hidden_deviation: f32,
    pub maximum_replay_state_deviation: f32,
    pub minimum_retained_vs_reset_hidden_deviation: f32,
    pub oracle_tolerance: f32,
    pub replay_tolerance: f32,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Copy, Debug)]
struct TextExecutionPolicy<'a> {
    rendered_chat_prompt: &'a str,
    prompt_token_limit: Option<usize>,
    generation_step_limit: usize,
}

#[derive(Clone, Debug)]
struct TextExecutionResult {
    model: ModelReceipt,
    tokenizer: TokenizerContractReceipt,
    dimensions: Dimensions,
    prompt_token_ids: Vec<usize>,
    prompt_token_ids_blake3: String,
    generation_step_limit: usize,
    generated_token_ids: Vec<usize>,
    generated_token_ids_blake3: String,
    generated_bytes_hex: String,
    generated_text: Option<String>,
    stop_reason: &'static str,
    steps: Vec<TextGenerationStepReceipt>,
    final_recurrent_states: NumericReceipt,
    maximum_oracle_state_deviation: f32,
    maximum_oracle_output_deviation: f32,
    maximum_replay_hidden_deviation: f32,
    maximum_replay_state_deviation: f32,
    minimum_retained_vs_reset_hidden_deviation: f32,
}

impl PromptRequest {
    pub fn validate(&self) -> Result<(), String> {
        let message_bytes = self.user_message.len();
        if message_bytes > PROMPT_MAX_MESSAGE_BYTES {
            return Err(format!(
                "user message has {message_bytes} bytes, exceeding package cap {PROMPT_MAX_MESSAGE_BYTES}"
            ));
        }
        if self.max_prompt_tokens == 0 || self.max_prompt_tokens > PROMPT_MAX_TOKEN_COUNT {
            return Err(format!(
                "max prompt tokens must be in 1..={PROMPT_MAX_TOKEN_COUNT}, found {}",
                self.max_prompt_tokens
            ));
        }
        if self.max_new_tokens == 0 || self.max_new_tokens > PROMPT_MAX_NEW_TOKEN_COUNT {
            return Err(format!(
                "max new tokens must be in 1..={PROMPT_MAX_NEW_TOKEN_COUNT}, found {}",
                self.max_new_tokens
            ));
        }
        Ok(())
    }

    pub fn render_chat_prompt(&self) -> Result<String, String> {
        self.validate()?;
        Ok(format!(
            "{TOKENIZER_SPECIAL_TEXT}User: {}{TOKENIZER_EOS_TEXT}Assistant:",
            self.user_message
        ))
    }
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
pub fn parse_prompt_arguments(arguments: &[String]) -> Result<PromptRequest, String> {
    if arguments.len() != PROMPT_EXPECTED_ARGUMENT_COUNT {
        return Err(format!(
            "rwkv-prompt-harness requires {PROMPT_MESSAGE_OPTION} TEXT {PROMPT_TOKEN_LIMIT_OPTION} COUNT {PROMPT_NEW_TOKEN_LIMIT_OPTION} COUNT"
        ));
    }

    let mut message = None;
    let mut prompt_token_limit = None;
    let mut new_token_limit = None;
    let mut index = 0_usize;
    while index < arguments.len() {
        let option = &arguments[index];
        let value_index = index
            .checked_add(1)
            .ok_or_else(|| "prompt argument index overflows usize".to_owned())?;
        let value = arguments
            .get(value_index)
            .ok_or_else(|| format!("option {option} requires a value"))?;
        match option.as_str() {
            PROMPT_MESSAGE_OPTION => {
                if message.replace(value.clone()).is_some() {
                    return Err(format!("duplicate option {PROMPT_MESSAGE_OPTION}"));
                }
            }
            PROMPT_TOKEN_LIMIT_OPTION => {
                if prompt_token_limit.is_some() {
                    return Err(format!("duplicate option {PROMPT_TOKEN_LIMIT_OPTION}"));
                }
                prompt_token_limit = Some(parse_positive_limit(value, PROMPT_TOKEN_LIMIT_OPTION)?);
            }
            PROMPT_NEW_TOKEN_LIMIT_OPTION => {
                if new_token_limit.is_some() {
                    return Err(format!("duplicate option {PROMPT_NEW_TOKEN_LIMIT_OPTION}"));
                }
                new_token_limit = Some(parse_positive_limit(value, PROMPT_NEW_TOKEN_LIMIT_OPTION)?);
            }
            _ => return Err(format!("unknown option {option}")),
        }
        index = value_index
            .checked_add(1)
            .ok_or_else(|| "prompt argument index overflows usize".to_owned())?;
    }

    let request = PromptRequest {
        user_message: message.ok_or_else(|| format!("missing option {PROMPT_MESSAGE_OPTION}"))?,
        max_prompt_tokens: prompt_token_limit
            .ok_or_else(|| format!("missing option {PROMPT_TOKEN_LIMIT_OPTION}"))?,
        max_new_tokens: new_token_limit
            .ok_or_else(|| format!("missing option {PROMPT_NEW_TOKEN_LIMIT_OPTION}"))?,
    };
    request.validate()?;
    Ok(request)
}

fn parse_positive_limit(value: &str, option: &str) -> Result<usize, String> {
    let parsed = value
        .parse::<usize>()
        .map_err(|error| format!("{option} requires a positive integer: {error}"))?;
    if parsed == 0 {
        return Err(format!("{option} requires a positive integer"));
    }
    Ok(parsed)
}

#[derive(Clone, Debug, Default)]
struct TokenTrieNode {
    children: BTreeMap<u8, usize>,
    token_id: Option<usize>,
}

#[derive(Clone, Debug)]
pub struct RwkvTokenizer {
    tokens: Vec<Option<Vec<u8>>>,
    trie: Vec<TokenTrieNode>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
struct RankedLogit {
    token_id: usize,
    logit: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
struct TopTwo {
    first: RankedLogit,
    second: RankedLogit,
}

#[derive(Clone, Debug)]
struct ModelSequenceResult {
    final_output: Vec<f32>,
    recurrent_states: Vec<f32>,
    layer_deviations: Vec<LayerDeviationReceipt>,
    maximum_state_deviation: f32,
    maximum_output_deviation: f32,
}

#[derive(Clone, Debug)]
struct HeadEvaluation {
    final_hidden: Vec<f32>,
    logits: Vec<f32>,
    top_two: TopTwo,
    head_oracle_logit_deviation: f32,
}

#[derive(Debug, Deserialize)]
struct TokenizerConfigFile {
    bos_token: String,
    eos_token: String,
    added_tokens_decoder: BTreeMap<String, AddedTokenFile>,
}

#[derive(Debug, Deserialize)]
struct AddedTokenFile {
    content: String,
    special: bool,
}

#[derive(Debug, Deserialize)]
struct TokenIdConfigFile {
    bos_token_id: usize,
    eos_token_id: usize,
}

#[derive(Debug, Deserialize)]
struct SpecialTokensMapFile {
    bos_token: String,
    eos_token: String,
    unk_token: String,
    pad_token: String,
}

impl RwkvTokenizer {
    pub fn parse(vocabulary: &[u8]) -> Result<Self, String> {
        let source = std::str::from_utf8(vocabulary)
            .map_err(|error| format!("tokenizer vocabulary is not UTF-8: {error}"))?;
        let lines = source.lines().collect::<Vec<_>>();
        if lines.len() != TOKENIZER_VOCAB_ENTRY_COUNT {
            return Err(format!(
                "tokenizer vocabulary requires {TOKENIZER_VOCAB_ENTRY_COUNT} rows, found {}",
                lines.len()
            ));
        }

        let token_capacity = TOKENIZER_LAST_VOCAB_ID
            .checked_add(1)
            .ok_or_else(|| "tokenizer ID capacity overflows usize".to_owned())?;
        let mut tokens = vec![None; token_capacity];
        let mut unique_tokens = BTreeSet::new();
        for (line_index, line) in lines.iter().enumerate() {
            let expected_id = line_index
                .checked_add(TOKENIZER_FIRST_VOCAB_ID)
                .ok_or_else(|| "tokenizer row ID overflows usize".to_owned())?;
            let (token_id, token_bytes) = parse_vocabulary_line(line)?;
            if token_id != expected_id {
                return Err(format!(
                    "tokenizer row {} must contain ID {expected_id}, found {token_id}",
                    line_index + 1
                ));
            }
            if token_bytes.is_empty() {
                return Err(format!("tokenizer ID {token_id} has an empty byte token"));
            }
            if !unique_tokens.insert(token_bytes.clone()) {
                return Err(format!(
                    "tokenizer ID {token_id} duplicates an earlier byte token"
                ));
            }
            tokens[token_id] = Some(token_bytes);
        }

        Self::from_tokens(tokens)
    }

    fn from_tokens(tokens: Vec<Option<Vec<u8>>>) -> Result<Self, String> {
        if tokens.len() <= TOKENIZER_FIRST_VOCAB_ID {
            return Err("tokenizer requires at least one ordinary byte token".to_owned());
        }
        let mut trie = vec![TokenTrieNode::default()];
        for (token_id, token) in tokens.iter().enumerate().skip(TOKENIZER_FIRST_VOCAB_ID) {
            let token = token
                .as_deref()
                .ok_or_else(|| format!("tokenizer vocabulary is missing ID {token_id}"))?;
            let mut node_index = 0_usize;
            for byte in token {
                let next_index = if let Some(index) = trie[node_index].children.get(byte) {
                    *index
                } else {
                    let index = trie.len();
                    trie.push(TokenTrieNode::default());
                    trie[node_index].children.insert(*byte, index);
                    index
                };
                node_index = next_index;
            }
            if trie[node_index].token_id.replace(token_id).is_some() {
                return Err(format!("tokenizer trie contains duplicate ID {token_id}"));
            }
        }

        Ok(Self { tokens, trie })
    }

    pub fn encode_bytes(&self, source: &[u8]) -> Result<Vec<usize>, String> {
        let mut token_ids = Vec::new();
        let mut offset = 0_usize;
        while offset < source.len() {
            let mut node_index = 0_usize;
            let mut cursor = offset;
            let mut longest = None;
            while cursor < source.len() {
                let Some(next_index) = self.trie[node_index].children.get(&source[cursor]) else {
                    break;
                };
                node_index = *next_index;
                cursor += 1;
                if let Some(token_id) = self.trie[node_index].token_id {
                    longest = Some((cursor, token_id));
                }
            }
            let (next_offset, token_id) = longest
                .ok_or_else(|| format!("tokenizer has no byte token at source offset {offset}"))?;
            if next_offset <= offset {
                return Err("tokenizer longest-prefix match did not advance".to_owned());
            }
            token_ids.push(token_id);
            offset = next_offset;
        }
        Ok(token_ids)
    }

    pub fn decode_bytes(&self, token_ids: &[usize]) -> Result<Vec<u8>, String> {
        let mut decoded = Vec::new();
        for token_id in token_ids {
            if *token_id == TOKENIZER_BOS_TOKEN_ID {
                return Err("special tokenizer ID 0 has no ordinary vocabulary bytes".to_owned());
            }
            let token = self
                .tokens
                .get(*token_id)
                .and_then(|token| token.as_deref())
                .ok_or_else(|| format!("tokenizer cannot decode vocabulary ID {token_id}"))?;
            decoded.extend_from_slice(token);
        }
        Ok(decoded)
    }

    fn encode_wrapper_text(&self, source: &str) -> Result<Vec<usize>, String> {
        let source = source.as_bytes();
        let bos = TOKENIZER_SPECIAL_TEXT.as_bytes();
        let eos = TOKENIZER_EOS_TEXT.as_bytes();
        let mut token_ids = Vec::new();
        let mut offset = 0_usize;
        while offset < source.len() {
            if source[offset..].starts_with(bos) {
                token_ids.push(TOKENIZER_BOS_TOKEN_ID);
                offset += bos.len();
                continue;
            }
            if source[offset..].starts_with(eos) {
                token_ids.push(TOKENIZER_WRAPPER_EOS_TOKEN_ID);
                offset += eos.len();
                continue;
            }
            let mut end = offset + 1;
            while end < source.len()
                && !source[end..].starts_with(bos)
                && !source[end..].starts_with(eos)
            {
                end += 1;
            }
            token_ids.extend(self.encode_bytes(&source[offset..end])?);
            offset = end;
        }
        Ok(token_ids)
    }

    fn decode_wrapper_bytes(&self, token_ids: &[usize]) -> Result<Vec<u8>, String> {
        let mut decoded = Vec::new();
        for token_id in token_ids {
            match *token_id {
                TOKENIZER_BOS_TOKEN_ID => {
                    decoded.extend_from_slice(TOKENIZER_SPECIAL_TEXT.as_bytes());
                }
                TOKENIZER_WRAPPER_EOS_TOKEN_ID => {
                    decoded.extend_from_slice(TOKENIZER_EOS_TEXT.as_bytes());
                }
                _ => decoded.extend_from_slice(&self.decode_bytes(&[*token_id])?),
            }
        }
        Ok(decoded)
    }
}

fn parse_vocabulary_line(line: &str) -> Result<(usize, Vec<u8>), String> {
    let (id_text, remainder) = line
        .split_once(' ')
        .ok_or_else(|| format!("tokenizer row has no ID separator: {line:?}"))?;
    let (literal, length_text) = remainder
        .rsplit_once(' ')
        .ok_or_else(|| format!("tokenizer row has no length separator: {line:?}"))?;
    let token_id = id_text
        .parse::<usize>()
        .map_err(|error| format!("invalid tokenizer ID {id_text:?}: {error}"))?;
    let declared_length = length_text
        .parse::<usize>()
        .map_err(|error| format!("invalid tokenizer byte length {length_text:?}: {error}"))?;
    let token_bytes = parse_python_bytes_literal(literal)?;
    if token_bytes.len() != declared_length {
        return Err(format!(
            "tokenizer ID {token_id} declares {declared_length} bytes but literal contains {}",
            token_bytes.len()
        ));
    }
    Ok((token_id, token_bytes))
}

fn parse_python_bytes_literal(literal: &str) -> Result<Vec<u8>, String> {
    let source = literal.as_bytes();
    let (bytes_mode, quote_index) = match source {
        [b'b', b'\'', ..] | [b'b', b'"', ..] => (true, 1_usize),
        [b'\'', ..] | [b'"', ..] => (false, 0_usize),
        _ => return Err(format!("unsupported tokenizer literal {literal:?}")),
    };
    let quote = source[quote_index];
    if source.len() <= quote_index + 1 || source.last().copied() != Some(quote) {
        return Err(format!("unterminated tokenizer literal {literal:?}"));
    }
    let end = source.len() - 1;
    let mut output = Vec::new();
    let mut index = quote_index + 1;
    while index < end {
        let byte = source[index];
        if byte != b'\\' {
            if byte == quote {
                return Err(format!("unescaped quote in tokenizer literal {literal:?}"));
            }
            if bytes_mode && !byte.is_ascii() {
                return Err(format!(
                    "non-ASCII source byte in bytes literal {literal:?}"
                ));
            }
            output.push(byte);
            index += 1;
            continue;
        }

        index += 1;
        if index >= end {
            return Err(format!("trailing escape in tokenizer literal {literal:?}"));
        }
        let escaped = source[index];
        index += 1;
        match escaped {
            b'\\' => output.push(b'\\'),
            b'\'' => output.push(b'\''),
            b'"' => output.push(b'"'),
            b'a' => output.push(ASCII_ALERT_BYTE),
            b'b' => output.push(ASCII_BACKSPACE_BYTE),
            b'f' => output.push(ASCII_FORM_FEED_BYTE),
            b'n' => output.push(b'\n'),
            b'r' => output.push(b'\r'),
            b't' => output.push(b'\t'),
            b'v' => output.push(ASCII_VERTICAL_TAB_BYTE),
            b'x' => {
                let value =
                    parse_fixed_hex(source, &mut index, end, PYTHON_BYTE_HEX_DIGITS, literal)?;
                if bytes_mode {
                    output.push(u8::try_from(value).map_err(|error| {
                        format!("hex byte escape is out of range in {literal:?}: {error}")
                    })?);
                } else {
                    let character = char::from_u32(value)
                        .ok_or_else(|| format!("invalid hex Unicode scalar in {literal:?}"))?;
                    let mut encoded = [0_u8; UTF8_MAX_BYTES_PER_SCALAR];
                    output.extend_from_slice(character.encode_utf8(&mut encoded).as_bytes());
                }
            }
            b'u' | b'U' => {
                if bytes_mode {
                    return Err(format!(
                        "Unicode escape in tokenizer bytes literal {literal:?}"
                    ));
                }
                let digits = if escaped == b'u' {
                    PYTHON_SHORT_UNICODE_HEX_DIGITS
                } else {
                    PYTHON_LONG_UNICODE_HEX_DIGITS
                };
                let value = parse_fixed_hex(source, &mut index, end, digits, literal)?;
                let character = char::from_u32(value).ok_or_else(|| {
                    format!("invalid Unicode scalar U+{value:04X} in {literal:?}")
                })?;
                let mut encoded = [0_u8; UTF8_MAX_BYTES_PER_SCALAR];
                output.extend_from_slice(character.encode_utf8(&mut encoded).as_bytes());
            }
            b'0'..=b'7' => {
                let mut value = u32::from(escaped - b'0');
                let mut digits = 1_usize;
                while digits < PYTHON_MAX_OCTAL_DIGITS
                    && index < end
                    && matches!(source[index], b'0'..=b'7')
                {
                    value = value * OCTAL_RADIX + u32::from(source[index] - b'0');
                    index += 1;
                    digits += 1;
                }
                if bytes_mode {
                    output.push(u8::try_from(value).map_err(|error| {
                        format!("octal byte escape is out of range in {literal:?}: {error}")
                    })?);
                } else {
                    let character = char::from_u32(value)
                        .ok_or_else(|| format!("invalid octal Unicode scalar in {literal:?}"))?;
                    let mut encoded = [0_u8; UTF8_MAX_BYTES_PER_SCALAR];
                    output.extend_from_slice(character.encode_utf8(&mut encoded).as_bytes());
                }
            }
            _ => {
                return Err(format!(
                    "unsupported escape \\{} in {literal:?}",
                    escaped as char
                ));
            }
        }
    }
    Ok(output)
}

fn parse_fixed_hex(
    source: &[u8],
    index: &mut usize,
    end: usize,
    digit_count: usize,
    literal: &str,
) -> Result<u32, String> {
    let next = index
        .checked_add(digit_count)
        .ok_or_else(|| "hex escape index overflows usize".to_owned())?;
    if next > end {
        return Err(format!("short hex escape in tokenizer literal {literal:?}"));
    }
    let mut value = 0_u32;
    for digit in &source[*index..next] {
        let digit_value = match digit {
            b'0'..=b'9' => u32::from(*digit - b'0'),
            b'a'..=b'f' => u32::from(*digit - b'a') + HEX_ALPHA_DIGIT_OFFSET,
            b'A'..=b'F' => u32::from(*digit - b'A') + HEX_ALPHA_DIGIT_OFFSET,
            _ => {
                return Err(format!(
                    "invalid hex escape in tokenizer literal {literal:?}"
                ));
            }
        };
        value = value
            .checked_mul(HEX_RADIX)
            .and_then(|partial| partial.checked_add(digit_value))
            .ok_or_else(|| format!("hex escape overflows in tokenizer literal {literal:?}"))?;
    }
    *index = next;
    Ok(value)
}

fn validate_reference_fixture(
    tokenizer: &RwkvTokenizer,
    name: &'static str,
    source: &[u8],
    expected_token_ids: &[usize],
) -> Result<TokenizerFixtureReceipt, String> {
    let token_ids = tokenizer.encode_bytes(source)?;
    if token_ids != expected_token_ids {
        return Err(format!(
            "tokenizer reference fixture {name} expected {expected_token_ids:?}, found {token_ids:?}"
        ));
    }
    let roundtrip = tokenizer.decode_bytes(&token_ids)?;
    if roundtrip != source {
        return Err(format!(
            "tokenizer reference fixture {name} did not round-trip exact bytes"
        ));
    }
    Ok(TokenizerFixtureReceipt {
        name,
        source_bytes_hex: encode_hex(source),
        token_ids,
        roundtrip_bytes_hex: encode_hex(&roundtrip),
    })
}

fn validate_wrapper_reference_fixture(
    tokenizer: &RwkvTokenizer,
    name: &'static str,
    source: &str,
    expected_token_ids: &[usize],
) -> Result<TokenizerFixtureReceipt, String> {
    let token_ids = tokenizer.encode_wrapper_text(source)?;
    if token_ids != expected_token_ids {
        return Err(format!(
            "tokenizer wrapper fixture {name} expected {expected_token_ids:?}, found {token_ids:?}"
        ));
    }
    let roundtrip = tokenizer.decode_wrapper_bytes(&token_ids)?;
    if roundtrip != source.as_bytes() {
        return Err(format!(
            "tokenizer wrapper fixture {name} did not round-trip exact text"
        ));
    }
    Ok(TokenizerFixtureReceipt {
        name,
        source_bytes_hex: encode_hex(source.as_bytes()),
        token_ids,
        roundtrip_bytes_hex: encode_hex(&roundtrip),
    })
}

fn authority_artifact_receipt(
    name: &'static str,
    bytes: &[u8],
    sha256_sri: &'static str,
    expected_blake3: &str,
) -> Result<AuthorityArtifactReceipt, String> {
    let actual_blake3 = blake3::hash(bytes).to_hex().to_string();
    if actual_blake3 != expected_blake3 {
        return Err(format!(
            "{name} BLAKE3 mismatch: expected {expected_blake3}, found {actual_blake3}"
        ));
    }
    let byte_count = u64::try_from(bytes.len())
        .map_err(|error| format!("{name} byte count does not fit u64: {error}"))?;
    Ok(AuthorityArtifactReceipt {
        name,
        sha256_sri,
        blake3: actual_blake3,
        byte_count,
    })
}

fn validate_tokenizer_authority(
    inputs: TokenizerAuthorityInputs<'_>,
) -> Result<(RwkvTokenizer, TokenizerContractReceipt), String> {
    let artifacts = vec![
        authority_artifact_receipt(
            "rwkv_vocab_v20230424.txt",
            inputs.vocabulary,
            TOKENIZER_VOCAB_SHA256_SRI,
            TOKENIZER_VOCAB_BLAKE3,
        )?,
        authority_artifact_receipt(
            "tokenizer_config.json",
            inputs.tokenizer_config,
            TOKENIZER_CONFIG_SHA256_SRI,
            TOKENIZER_CONFIG_BLAKE3,
        )?,
        authority_artifact_receipt(
            "added_tokens.json",
            inputs.added_tokens,
            ADDED_TOKENS_SHA256_SRI,
            ADDED_TOKENS_BLAKE3,
        )?,
        authority_artifact_receipt(
            "hf_rwkv_tokenizer.py",
            inputs.tokenizer_implementation,
            TOKENIZER_IMPLEMENTATION_SHA256_SRI,
            TOKENIZER_IMPLEMENTATION_BLAKE3,
        )?,
        authority_artifact_receipt(
            "special_tokens_map.json",
            inputs.special_tokens_map,
            SPECIAL_TOKENS_MAP_SHA256_SRI,
            SPECIAL_TOKENS_MAP_BLAKE3,
        )?,
        authority_artifact_receipt(
            "config.json",
            inputs.model_config,
            MODEL_CONFIG_SHA256_SRI,
            MODEL_CONFIG_BLAKE3,
        )?,
        authority_artifact_receipt(
            "generation_config.json",
            inputs.generation_config,
            GENERATION_CONFIG_SHA256_SRI,
            GENERATION_CONFIG_BLAKE3,
        )?,
    ];
    if artifacts[0].byte_count != TOKENIZER_VOCAB_BYTE_COUNT {
        return Err(format!(
            "tokenizer vocabulary must contain {TOKENIZER_VOCAB_BYTE_COUNT} bytes, found {}",
            artifacts[0].byte_count
        ));
    }

    let tokenizer_config: TokenizerConfigFile = serde_json::from_slice(inputs.tokenizer_config)
        .map_err(|error| format!("invalid tokenizer_config.json: {error}"))?;
    let added_tokens: BTreeMap<String, usize> = serde_json::from_slice(inputs.added_tokens)
        .map_err(|error| format!("invalid added_tokens.json: {error}"))?;
    let special_tokens: SpecialTokensMapFile = serde_json::from_slice(inputs.special_tokens_map)
        .map_err(|error| format!("invalid special_tokens_map.json: {error}"))?;
    let model_config: TokenIdConfigFile = serde_json::from_slice(inputs.model_config)
        .map_err(|error| format!("invalid config.json token IDs: {error}"))?;
    let generation_config: TokenIdConfigFile = serde_json::from_slice(inputs.generation_config)
        .map_err(|error| format!("invalid generation_config.json token IDs: {error}"))?;

    let added_decoder = tokenizer_config
        .added_tokens_decoder
        .get(&TOKENIZER_BOS_TOKEN_ID.to_string())
        .ok_or_else(|| "tokenizer config is missing added special ID 0".to_owned())?;
    if tokenizer_config.added_tokens_decoder.len() != 1
        || added_decoder.content != TOKENIZER_SPECIAL_TEXT
        || !added_decoder.special
        || added_tokens.len() != 1
        || added_tokens.get(TOKENIZER_SPECIAL_TEXT) != Some(&TOKENIZER_BOS_TOKEN_ID)
    {
        return Err("tokenizer added special token contract does not match ID 0".to_owned());
    }
    if tokenizer_config.bos_token != TOKENIZER_SPECIAL_TEXT
        || tokenizer_config.eos_token != TOKENIZER_EOS_TEXT
        || special_tokens.bos_token != TOKENIZER_SPECIAL_TEXT
        || special_tokens.eos_token != TOKENIZER_EOS_TEXT
        || special_tokens.unk_token != TOKENIZER_SPECIAL_TEXT
        || special_tokens.pad_token != TOKENIZER_SPECIAL_TEXT
    {
        return Err("tokenizer special-token text contract is inconsistent".to_owned());
    }
    if model_config.bos_token_id != MODEL_CONFIG_BOS_TOKEN_ID
        || model_config.eos_token_id != MODEL_CONFIG_EOS_TOKEN_ID
        || generation_config.bos_token_id != GENERATION_CONFIG_BOS_TOKEN_ID
        || generation_config.eos_token_id != GENERATION_CONFIG_EOS_TOKEN_ID
    {
        return Err("model or generation BOS/EOS IDs changed".to_owned());
    }
    let implementation = std::str::from_utf8(inputs.tokenizer_implementation)
        .map_err(|error| format!("tokenizer implementation is not UTF-8: {error}"))?;
    if !implementation.contains("rwkv_vocab_v20230424.txt")
        || !implementation.contains("find_longest")
        || !implementation.contains("decodeBytes")
    {
        return Err("tokenizer implementation lacks reviewed byte-trie markers".to_owned());
    }

    let tokenizer = RwkvTokenizer::parse(inputs.vocabulary)?;
    let eos_ids = tokenizer.encode_bytes(TOKENIZER_EOS_TEXT.as_bytes())?;
    if eos_ids != [BYTE_VOCABULARY_EOS_TOKEN_ID] {
        return Err(format!(
            "byte-vocabulary EOS text must encode to [{}], found {eos_ids:?}",
            BYTE_VOCABULARY_EOS_TOKEN_ID
        ));
    }
    let reference_fixtures = vec![
        validate_reference_fixture(&tokenizer, "empty", b"", REFERENCE_EMPTY_TOKEN_IDS)?,
        validate_reference_fixture(
            &tokenizer,
            "tokenizer_eos",
            TOKENIZER_EOS_TEXT.as_bytes(),
            REFERENCE_EOS_TOKEN_IDS,
        )?,
        validate_reference_fixture(
            &tokenizer,
            "overlapping_prefix",
            b"aaaa",
            REFERENCE_OVERLAP_TOKEN_IDS,
        )?,
        validate_reference_fixture(&tokenizer, "ascii", b"hello", REFERENCE_ASCII_TOKEN_IDS)?,
        validate_reference_fixture(
            &tokenizer,
            "unicode",
            "RWKV λ 世界".as_bytes(),
            REFERENCE_UNICODE_TOKEN_IDS,
        )?,
        validate_reference_fixture(
            &tokenizer,
            "control_bytes",
            &[0, 1, u8::MAX],
            REFERENCE_CONTROL_TOKEN_IDS,
        )?,
        validate_reference_fixture(
            &tokenizer,
            "byte_fixed_chat_prompt",
            FIXED_CHAT_PROMPT.as_bytes(),
            REFERENCE_BYTE_PROMPT_TOKEN_IDS,
        )?,
        validate_wrapper_reference_fixture(
            &tokenizer,
            "wrapper_fixed_chat_prompt",
            FIXED_RENDERED_CHAT_PROMPT,
            REFERENCE_WRAPPER_PROMPT_TOKEN_IDS,
        )?,
    ];

    Ok((
        tokenizer,
        TokenizerContractReceipt {
            revision: MODEL_REVISION,
            vocabulary_entry_count: TOKENIZER_VOCAB_ENTRY_COUNT,
            vocabulary_first_id: TOKENIZER_FIRST_VOCAB_ID,
            vocabulary_last_id: TOKENIZER_LAST_VOCAB_ID,
            model_config_bos_token_id: MODEL_CONFIG_BOS_TOKEN_ID,
            model_config_eos_token_id: MODEL_CONFIG_EOS_TOKEN_ID,
            tokenizer_bos_token_id: TOKENIZER_BOS_TOKEN_ID,
            byte_vocabulary_eos_token_id: BYTE_VOCABULARY_EOS_TOKEN_ID,
            tokenizer_wrapper_eos_token_id: TOKENIZER_WRAPPER_EOS_TOKEN_ID,
            generation_config_bos_token_id: GENERATION_CONFIG_BOS_TOKEN_ID,
            generation_config_eos_token_id: GENERATION_CONFIG_EOS_TOKEN_ID,
            reference_fixtures,
            artifacts,
        },
    ))
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer]
pub fn run_checkpoint(checkpoint: &[u8], expected_blake3: &str) -> Result<LayerReceipt, String> {
    verify_checkpoint_digest(checkpoint, expected_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = load_layer_zero(&tensors, dimensions)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let result = run_sequence(&weights, [&model_config_bos, &model_config_eos])?;

    if result.maximum_state_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "recurrence state deviation {} exceeds tolerance {ORACLE_TOLERANCE}",
            result.maximum_state_deviation
        ));
    }
    if result.maximum_output_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "recurrence output deviation {} exceeds tolerance {ORACLE_TOLERANCE}",
            result.maximum_output_deviation
        ));
    }

    Ok(LayerReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        dimensions,
        layer_index: LAYER_INDEX,
        token_ids: [MODEL_CONFIG_BOS_TOKEN_ID, MODEL_CONFIG_EOS_TOKEN_ID],
        arithmetic_precision: ARITHMETIC_PRECISION,
        second_token_wkv: WkvReceipt {
            r: numeric_receipt(&result.second_preparation.wkv_inputs.r)?,
            w: numeric_receipt(&result.second_preparation.wkv_inputs.w)?,
            k: numeric_receipt(&result.second_preparation.wkv_inputs.k)?,
            v: numeric_receipt(&result.second_preparation.wkv_inputs.v)?,
            a: numeric_receipt(&result.second_preparation.wkv_inputs.a)?,
            b: numeric_receipt(&result.second_preparation.wkv_inputs.b)?,
        },
        final_state: numeric_receipt(&result.final_state)?,
        final_layer_output: numeric_receipt(&result.final_output)?,
        maximum_oracle_state_deviation: result.maximum_state_deviation,
        maximum_oracle_output_deviation: result.maximum_output_deviation,
        oracle_tolerance: ORACLE_TOLERANCE,
        non_claims: NON_CLAIMS.to_vec(),
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
pub fn run_ttwkv7_boundary_checkpoint(
    checkpoint: &[u8],
    expected_blake3: &str,
) -> Result<Ttwkv7BoundaryReceipt, String> {
    verify_checkpoint_digest(checkpoint, expected_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = load_layer_zero(&tensors, dimensions)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let result = run_sequence(&weights, [&model_config_bos, &model_config_eos])?;

    let vector_shape = [dimensions.head_count, dimensions.head_size];
    let state_shape = [
        dimensions.head_count,
        dimensions.head_size,
        dimensions.head_size,
    ];
    let encoded_a =
        encode_bf16_artifact("a", &vector_shape, &result.second_preparation.wkv_inputs.a)?;
    let encoded_w =
        encode_bf16_artifact("w", &vector_shape, &result.second_preparation.wkv_inputs.w)?;
    let encoded_k =
        encode_bf16_artifact("k", &vector_shape, &result.second_preparation.wkv_inputs.k)?;
    let encoded_v =
        encode_bf16_artifact("v", &vector_shape, &result.second_preparation.wkv_inputs.v)?;
    let encoded_r =
        encode_bf16_artifact("r", &vector_shape, &result.second_preparation.wkv_inputs.r)?;
    let encoded_b =
        encode_bf16_artifact("b", &vector_shape, &result.second_preparation.wkv_inputs.b)?;
    let encoded_pre_state =
        encode_bf16_artifact("pre_state", &state_shape, &result.second_pre_state)?;

    let quantized_a = decode_bf16_bytes(&encoded_a.bytes, "a")?;
    let quantized_w = decode_bf16_bytes(&encoded_w.bytes, "w")?;
    let quantized_k = decode_bf16_bytes(&encoded_k.bytes, "k")?;
    let quantized_v = decode_bf16_bytes(&encoded_v.bytes, "v")?;
    let quantized_r = decode_bf16_bytes(&encoded_r.bytes, "r")?;
    let quantized_b = decode_bf16_bytes(&encoded_b.bytes, "b")?;
    let quantized_pre_state = decode_bf16_bytes(&encoded_pre_state.bytes, "pre_state")?;
    let quantized_inputs = WkvInputs {
        r: quantized_r.clone(),
        w: quantized_w.clone(),
        k: quantized_k.clone(),
        v: quantized_v.clone(),
        a: quantized_a.clone(),
        b: quantized_b.clone(),
    };
    let (matrix_post_state, matrix_output) =
        wkv_step_matrix(&quantized_pre_state, &quantized_inputs, dimensions)?;
    let (oracle_post_state, oracle_output) =
        wkv_step_oracle(&quantized_pre_state, &quantized_inputs, dimensions)?;
    let matrix_oracle_state_deviation = max_abs_difference(&matrix_post_state, &oracle_post_state)?;
    let matrix_oracle_output_deviation = max_abs_difference(&matrix_output, &oracle_output)?;
    if matrix_oracle_state_deviation > ORACLE_TOLERANCE
        || matrix_oracle_output_deviation > ORACLE_TOLERANCE
    {
        return Err(format!(
            "BF16 boundary recurrence deviations {matrix_oracle_state_deviation} and {matrix_oracle_output_deviation} exceed {ORACLE_TOLERANCE}"
        ));
    }

    let encoded_output = encode_bf16_artifact("expected_output", &vector_shape, &matrix_output)?;
    let encoded_post_state =
        encode_bf16_artifact("expected_post_state", &state_shape, &matrix_post_state)?;
    let retained_pre_state_maximum_absolute_value =
        maximum_absolute_value(&quantized_pre_state, "quantized retained pre-state")?;
    if retained_pre_state_maximum_absolute_value <= TTWKV7_BOUNDARY_NONZERO_FLOOR {
        return Err(format!(
            "retained BF16 pre-state maximum {retained_pre_state_maximum_absolute_value} does not exceed {TTWKV7_BOUNDARY_NONZERO_FLOOR}"
        ));
    }

    let input_quantization_deviations = [
        max_abs_difference(&result.second_preparation.wkv_inputs.a, &quantized_a)?,
        max_abs_difference(&result.second_preparation.wkv_inputs.w, &quantized_w)?,
        max_abs_difference(&result.second_preparation.wkv_inputs.k, &quantized_k)?,
        max_abs_difference(&result.second_preparation.wkv_inputs.v, &quantized_v)?,
        max_abs_difference(&result.second_preparation.wkv_inputs.r, &quantized_r)?,
        max_abs_difference(&result.second_preparation.wkv_inputs.b, &quantized_b)?,
    ];
    let maximum_input_quantization_deviation = input_quantization_deviations
        .into_iter()
        .fold(0.0_f32, f32::max);
    let pre_state_quantization_deviation =
        max_abs_difference(&result.second_pre_state, &quantized_pre_state)?;
    let expected_output_vs_source_deviation =
        max_abs_difference(&result.second_raw_output, &matrix_output)?;
    let expected_post_state_vs_source_deviation =
        max_abs_difference(&result.final_state, &matrix_post_state)?;

    let input_artifacts = vec![
        encoded_a.receipt.clone(),
        encoded_w.receipt.clone(),
        encoded_k.receipt.clone(),
        encoded_v.receipt.clone(),
        encoded_r.receipt.clone(),
        encoded_b.receipt.clone(),
    ];
    let ordered_artifacts = vec![
        encoded_a.receipt,
        encoded_w.receipt,
        encoded_k.receipt,
        encoded_v.receipt,
        encoded_r.receipt,
        encoded_b.receipt,
        encoded_pre_state.receipt.clone(),
        encoded_output.receipt.clone(),
        encoded_post_state.receipt.clone(),
    ];
    let ordered_artifact_blake3 = ordered_artifact_blake3(&ordered_artifacts)?;

    Ok(Ttwkv7BoundaryReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        dimensions,
        layer_index: LAYER_INDEX,
        prefix_token_ids: [MODEL_CONFIG_BOS_TOKEN_ID, MODEL_CONFIG_EOS_TOKEN_ID],
        target: TTWKV7_BOUNDARY_TARGET,
        arithmetic_precision: TTWKV7_BOUNDARY_PRECISION,
        byte_order: TTWKV7_BOUNDARY_BYTE_ORDER,
        vector_order: TTWKV7_BOUNDARY_VECTOR_ORDER,
        state_order: TTWKV7_BOUNDARY_STATE_ORDER,
        output_order: TTWKV7_BOUNDARY_OUTPUT_ORDER,
        input_order: TTWKV7_BOUNDARY_INPUT_ORDER,
        source_fp32_inputs: WkvReceipt {
            r: numeric_receipt(&result.second_preparation.wkv_inputs.r)?,
            w: numeric_receipt(&result.second_preparation.wkv_inputs.w)?,
            k: numeric_receipt(&result.second_preparation.wkv_inputs.k)?,
            v: numeric_receipt(&result.second_preparation.wkv_inputs.v)?,
            a: numeric_receipt(&result.second_preparation.wkv_inputs.a)?,
            b: numeric_receipt(&result.second_preparation.wkv_inputs.b)?,
        },
        source_fp32_pre_state: numeric_receipt(&result.second_pre_state)?,
        source_fp32_raw_output: numeric_receipt(&result.second_raw_output)?,
        source_fp32_post_state: numeric_receipt(&result.final_state)?,
        input_artifacts,
        pre_state_artifact: encoded_pre_state.receipt,
        expected_output_artifact: encoded_output.receipt,
        expected_post_state_artifact: encoded_post_state.receipt,
        ordered_artifact_blake3,
        maximum_input_quantization_deviation,
        pre_state_quantization_deviation,
        expected_output_vs_source_deviation,
        expected_post_state_vs_source_deviation,
        matrix_oracle_output_deviation,
        matrix_oracle_state_deviation,
        retained_pre_state_maximum_absolute_value,
        oracle_tolerance: ORACLE_TOLERANCE,
        non_claims: TTWKV7_BOUNDARY_NON_CLAIMS.to_vec(),
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.greedy_token]
pub fn run_token_checkpoint(
    checkpoint: &[u8],
    expected_blake3: &str,
) -> Result<TokenReceipt, String> {
    verify_checkpoint_digest(checkpoint, expected_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = (0..MODEL_LAYER_COUNT)
        .map(|layer_index| load_layer(&tensors, dimensions, layer_index))
        .collect::<Result<Vec<_>, _>>()?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let sequence = run_model_sequence(&weights, [&model_config_bos, &model_config_eos])?;

    if sequence.maximum_state_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "full-model recurrence state deviation {} exceeds tolerance {ORACLE_TOLERANCE}",
            sequence.maximum_state_deviation
        ));
    }
    if sequence.maximum_output_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "full-model recurrence output deviation {} exceeds tolerance {ORACLE_TOLERANCE}",
            sequence.maximum_output_deviation
        ));
    }

    let final_norm_weight = vector(&tensors, "model.norm.weight", dimensions.hidden_size)?;
    let final_norm_bias = vector(&tensors, "model.norm.bias", dimensions.hidden_size)?;
    let final_hidden = layer_norm(
        &sequence.final_output,
        &final_norm_weight,
        &final_norm_bias,
        LAYER_NORM_EPSILON,
    )?;
    let head_tensor = tensors
        .tensor("lm_head.weight")
        .map_err(|error| format!("missing lm_head.weight: {error}"))?;
    let head = matrix(
        &tensors,
        "lm_head.weight",
        VOCABULARY_SIZE,
        dimensions.hidden_size,
    )?;
    let logits = matvec(&head, &final_hidden)?;
    let production_top = rank_top_two(
        logits
            .iter()
            .copied()
            .enumerate()
            .map(|(token_id, logit)| RankedLogit { token_id, logit }),
    )?;
    let oracle_top = direct_bf16_head_top_two(&head_tensor, &final_hidden, dimensions.hidden_size)?;
    if production_top.first.token_id != oracle_top.first.token_id
        || production_top.second.token_id != oracle_top.second.token_id
    {
        return Err(format!(
            "LM-head ranking mismatch: production [{}, {}], direct oracle [{}, {}]",
            production_top.first.token_id,
            production_top.second.token_id,
            oracle_top.first.token_id,
            oracle_top.second.token_id
        ));
    }
    let head_oracle_logit_deviation = (production_top.first.logit - oracle_top.first.logit)
        .abs()
        .max((production_top.second.logit - oracle_top.second.logit).abs());
    if head_oracle_logit_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "LM-head oracle logit deviation {head_oracle_logit_deviation} exceeds tolerance {ORACLE_TOLERANCE}"
        ));
    }
    let greedy_margin = production_top.first.logit - production_top.second.logit;
    if !greedy_margin.is_finite() || greedy_margin < 0.0 {
        return Err(format!("invalid greedy margin {greedy_margin}"));
    }

    Ok(TokenReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        dimensions,
        layer_count: MODEL_LAYER_COUNT,
        prefix_token_ids: [MODEL_CONFIG_BOS_TOKEN_ID, MODEL_CONFIG_EOS_TOKEN_ID],
        generated_token_id: production_top.first.token_id,
        generated_logit: production_top.first.logit,
        runner_up_token_id: production_top.second.token_id,
        runner_up_logit: production_top.second.logit,
        greedy_margin,
        arithmetic_precision: ARITHMETIC_PRECISION,
        final_hidden: numeric_receipt(&final_hidden)?,
        logits: numeric_receipt(&logits)?,
        recurrent_states: numeric_receipt(&sequence.recurrent_states)?,
        layer_oracle_deviations: sequence.layer_deviations,
        maximum_oracle_state_deviation: sequence.maximum_state_deviation,
        maximum_oracle_output_deviation: sequence.maximum_output_deviation,
        head_oracle_logit_deviation,
        oracle_tolerance: ORACLE_TOLERANCE,
        non_claims: TOKEN_NON_CLAIMS.to_vec(),
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
pub fn run_framework_vector_fixture(
    checkpoint: &[u8],
    expected_blake3: &str,
) -> Result<FrameworkVectorFixture, String> {
    verify_checkpoint_digest(checkpoint, expected_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = (0..MODEL_LAYER_COUNT)
        .map(|layer_index| load_layer(&tensors, dimensions, layer_index))
        .collect::<Result<Vec<_>, _>>()?;
    validate_model_weights(&weights)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let model_config_bos = embedding_row(
        &embedding,
        MODEL_CONFIG_BOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let model_config_eos = embedding_row(
        &embedding,
        MODEL_CONFIG_EOS_TOKEN_ID,
        dimensions.hidden_size,
    )?;
    let sequence = run_model_sequence(&weights, [&model_config_bos, &model_config_eos])?;
    if sequence.maximum_state_deviation > ORACLE_TOLERANCE
        || sequence.maximum_output_deviation > ORACLE_TOLERANCE
    {
        return Err("framework fixture recurrence oracle exceeded tolerance".to_owned());
    }

    let final_norm_weight = vector(&tensors, "model.norm.weight", dimensions.hidden_size)?;
    let final_norm_bias = vector(&tensors, "model.norm.bias", dimensions.hidden_size)?;
    let final_hidden = layer_norm(
        &sequence.final_output,
        &final_norm_weight,
        &final_norm_bias,
        LAYER_NORM_EPSILON,
    )?;
    let head_tensor = tensors
        .tensor("lm_head.weight")
        .map_err(|error| format!("missing lm_head.weight: {error}"))?;
    let head = matrix(
        &tensors,
        "lm_head.weight",
        VOCABULARY_SIZE,
        dimensions.hidden_size,
    )?;
    let logits = matvec(&head, &final_hidden)?;
    let production_top = rank_top_two(
        logits
            .iter()
            .copied()
            .enumerate()
            .map(|(token_id, logit)| RankedLogit { token_id, logit }),
    )?;
    let oracle_top = direct_bf16_head_top_two(&head_tensor, &final_hidden, dimensions.hidden_size)?;
    if production_top.first.token_id != oracle_top.first.token_id
        || production_top.second.token_id != oracle_top.second.token_id
    {
        return Err(
            "framework fixture LM-head ranking disagrees with direct BF16 audit".to_owned(),
        );
    }
    let head_deviation = (production_top.first.logit - oracle_top.first.logit)
        .abs()
        .max((production_top.second.logit - oracle_top.second.logit).abs());
    if head_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "framework fixture LM-head deviation {head_deviation} exceeds {ORACLE_TOLERANCE}"
        ));
    }

    Ok(FrameworkVectorFixture {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        dimensions,
        layer_count: MODEL_LAYER_COUNT,
        prefix_token_ids: [MODEL_CONFIG_BOS_TOKEN_ID, MODEL_CONFIG_EOS_TOKEN_ID],
        arithmetic_precision: ARITHMETIC_PRECISION,
        final_hidden,
        logits,
        recurrent_states: sequence.recurrent_states,
        generated_token_id: production_top.first.token_id,
        generated_logit: production_top.first.logit,
        runner_up_token_id: production_top.second.token_id,
        runner_up_logit: production_top.second.logit,
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
pub fn run_decode_checkpoint(
    checkpoint: &[u8],
    expected_blake3: &str,
) -> Result<DecodeReceipt, String> {
    verify_checkpoint_digest(checkpoint, expected_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = (0..MODEL_LAYER_COUNT)
        .map(|layer_index| load_layer(&tensors, dimensions, layer_index))
        .collect::<Result<Vec<_>, _>>()?;
    validate_model_weights(&weights)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let final_norm_weight = vector(&tensors, "model.norm.weight", dimensions.hidden_size)?;
    let final_norm_bias = vector(&tensors, "model.norm.bias", dimensions.hidden_size)?;
    let head_tensor = tensors
        .tensor("lm_head.weight")
        .map_err(|error| format!("missing lm_head.weight: {error}"))?;
    let head = matrix(
        &tensors,
        "lm_head.weight",
        VOCABULARY_SIZE,
        dimensions.hidden_size,
    )?;

    let mut execution = ModelExecutionState::zero(dimensions)?;
    let mut input_token_id = MODEL_CONFIG_BOS_TOKEN_ID;
    let mut processed_input_ids = Vec::with_capacity(DECODE_STEP_COUNT);
    let mut generated_token_ids = Vec::with_capacity(DECODE_STEP_COUNT);
    let mut model_config_eos_observed_steps = Vec::new();
    let mut steps = Vec::with_capacity(DECODE_STEP_COUNT);
    let mut maximum_replay_hidden_deviation = 0.0_f32;
    let mut maximum_replay_logits_deviation = 0.0_f32;
    let mut maximum_replay_state_deviation = 0.0_f32;
    let mut minimum_retained_vs_reset_hidden_deviation = f32::INFINITY;

    for step_index in 0..DECODE_STEP_COUNT {
        let token_embedding = embedding_row(&embedding, input_token_id, dimensions.hidden_size)?;
        let (next_execution, final_output) =
            run_model_token(&weights, &token_embedding, execution)?;
        execution = next_execution;
        processed_input_ids.push(input_token_id);
        ensure_oracle_tolerance(&execution, "incremental")?;
        let evaluation = evaluate_head(
            &final_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let incremental_states = execution.flattened_matrices();

        let (replay_execution, replay_output) =
            replay_input_ids(&weights, &embedding, &processed_input_ids, dimensions)?;
        ensure_oracle_tolerance(&replay_execution, "replay")?;
        let replay_evaluation = evaluate_head(
            &replay_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let replay_states = replay_execution.flattened_matrices();
        let (_, reset_output) =
            replay_input_ids(&weights, &embedding, &[input_token_id], dimensions)?;
        let reset_evaluation = evaluate_head(
            &reset_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let retained_vs_reset_hidden_deviation =
            max_abs_difference(&evaluation.final_hidden, &reset_evaluation.final_hidden)?;
        if step_index == LAYER_INDEX {
            require_replay_tolerance(
                retained_vs_reset_hidden_deviation,
                "zero-state control",
                step_index,
            )?;
        } else {
            require_state_carry_divergence(retained_vs_reset_hidden_deviation, step_index)?;
            minimum_retained_vs_reset_hidden_deviation =
                minimum_retained_vs_reset_hidden_deviation.min(retained_vs_reset_hidden_deviation);
        }
        let hidden_deviation =
            max_abs_difference(&evaluation.final_hidden, &replay_evaluation.final_hidden)?;
        let logits_deviation = max_abs_difference(&evaluation.logits, &replay_evaluation.logits)?;
        let state_deviation = max_abs_difference(&incremental_states, &replay_states)?;
        require_replay_tolerance(hidden_deviation, "final hidden", step_index)?;
        require_replay_tolerance(logits_deviation, "logits", step_index)?;
        require_replay_tolerance(state_deviation, "recurrent state", step_index)?;
        if evaluation.top_two.first.token_id != replay_evaluation.top_two.first.token_id
            || evaluation.top_two.second.token_id != replay_evaluation.top_two.second.token_id
        {
            return Err(format!(
                "decode step {step_index} incremental/replay ranking mismatch"
            ));
        }
        maximum_replay_hidden_deviation = maximum_replay_hidden_deviation.max(hidden_deviation);
        maximum_replay_logits_deviation = maximum_replay_logits_deviation.max(logits_deviation);
        maximum_replay_state_deviation = maximum_replay_state_deviation.max(state_deviation);

        let generated = evaluation.top_two.first;
        let runner_up = evaluation.top_two.second;
        let greedy_margin = generated.logit - runner_up.logit;
        if !greedy_margin.is_finite() || greedy_margin < 0.0 {
            return Err(format!(
                "decode step {step_index} has invalid greedy margin {greedy_margin}"
            ));
        }
        let model_config_eos_selected = generated.token_id == MODEL_CONFIG_EOS_TOKEN_ID;
        if model_config_eos_selected {
            model_config_eos_observed_steps.push(step_index);
        }
        generated_token_ids.push(generated.token_id);
        steps.push(DecodeStepReceipt {
            step_index,
            input_token_id,
            generated_token_id: generated.token_id,
            generated_logit: generated.logit,
            runner_up_token_id: runner_up.token_id,
            runner_up_logit: runner_up.logit,
            greedy_margin,
            model_config_eos_selected,
            final_hidden: numeric_receipt(&evaluation.final_hidden)?,
            logits: numeric_receipt(&evaluation.logits)?,
            recurrent_states: numeric_receipt(&incremental_states)?,
            layer_oracle_deviations: layer_deviation_receipts(&execution),
            incremental_replay_hidden_deviation: hidden_deviation,
            incremental_replay_logits_deviation: logits_deviation,
            incremental_replay_state_deviation: state_deviation,
            retained_vs_reset_hidden_deviation,
            head_oracle_logit_deviation: evaluation.head_oracle_logit_deviation,
        });
        input_token_id = generated.token_id;
    }

    validate_decode_chain(&processed_input_ids, &generated_token_ids)?;
    if !minimum_retained_vs_reset_hidden_deviation.is_finite() {
        return Err("stateful decode did not execute a retained-state discriminator".to_owned());
    }
    let continued_after_model_config_eos = model_config_eos_observed_steps
        .iter()
        .any(|step_index| step_index + 1 < DECODE_STEP_COUNT);
    let maximum_oracle_state_deviation = execution
        .maximum_state_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    let maximum_oracle_output_deviation = execution
        .maximum_output_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    let final_recurrent_states = execution.flattened_matrices();

    Ok(DecodeReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        dimensions,
        layer_count: MODEL_LAYER_COUNT,
        seed_token_id: MODEL_CONFIG_BOS_TOKEN_ID,
        generated_step_count: DECODE_STEP_COUNT,
        processed_input_ids,
        generated_token_ids,
        model_config_eos_token_id: MODEL_CONFIG_EOS_TOKEN_ID,
        model_config_eos_observed_steps,
        continued_after_model_config_eos,
        arithmetic_precision: ARITHMETIC_PRECISION,
        steps,
        final_recurrent_states: numeric_receipt(&final_recurrent_states)?,
        maximum_oracle_state_deviation,
        maximum_oracle_output_deviation,
        maximum_replay_hidden_deviation,
        maximum_replay_logits_deviation,
        maximum_replay_state_deviation,
        minimum_retained_vs_reset_hidden_deviation,
        oracle_tolerance: ORACLE_TOLERANCE,
        replay_tolerance: REPLAY_TOLERANCE,
        non_claims: DECODE_NON_CLAIMS.to_vec(),
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
pub fn run_text_checkpoint(
    checkpoint: &[u8],
    expected_model_blake3: &str,
    authority_inputs: TokenizerAuthorityInputs<'_>,
) -> Result<TextReceipt, String> {
    let execution = run_text_execution(
        checkpoint,
        expected_model_blake3,
        authority_inputs,
        TextExecutionPolicy {
            rendered_chat_prompt: FIXED_RENDERED_CHAT_PROMPT,
            prompt_token_limit: None,
            generation_step_limit: TEXT_GENERATION_STEP_LIMIT,
        },
    )?;
    let generated_text = execution
        .generated_text
        .clone()
        .ok_or_else(|| "fixed bounded generated bytes are not complete UTF-8".to_owned())?;
    Ok(TextReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: execution.model,
        tokenizer: execution.tokenizer,
        dimensions: execution.dimensions,
        fixed_user_message: FIXED_USER_MESSAGE,
        fixed_chat_prompt: FIXED_CHAT_PROMPT,
        rendered_chat_prompt: FIXED_RENDERED_CHAT_PROMPT,
        prompt_token_ids: execution.prompt_token_ids,
        prompt_token_ids_blake3: execution.prompt_token_ids_blake3,
        generation_step_limit: execution.generation_step_limit,
        generated_token_ids: execution.generated_token_ids,
        generated_token_ids_blake3: execution.generated_token_ids_blake3,
        generated_bytes_hex: execution.generated_bytes_hex,
        generated_text,
        stop_reason: execution.stop_reason,
        arithmetic_precision: ARITHMETIC_PRECISION,
        steps: execution.steps,
        final_recurrent_states: execution.final_recurrent_states,
        maximum_oracle_state_deviation: execution.maximum_oracle_state_deviation,
        maximum_oracle_output_deviation: execution.maximum_oracle_output_deviation,
        maximum_replay_hidden_deviation: execution.maximum_replay_hidden_deviation,
        maximum_replay_state_deviation: execution.maximum_replay_state_deviation,
        minimum_retained_vs_reset_hidden_deviation: execution
            .minimum_retained_vs_reset_hidden_deviation,
        oracle_tolerance: ORACLE_TOLERANCE,
        replay_tolerance: REPLAY_TOLERANCE,
        non_claims: TEXT_NON_CLAIMS.to_vec(),
    })
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
pub fn run_prompt_checkpoint(
    checkpoint: &[u8],
    expected_model_blake3: &str,
    authority_inputs: TokenizerAuthorityInputs<'_>,
    request: PromptRequest,
) -> Result<PromptReceipt, String> {
    request.validate()?;
    let rendered_chat_prompt = request.render_chat_prompt()?;
    let execution = run_text_execution(
        checkpoint,
        expected_model_blake3,
        authority_inputs,
        TextExecutionPolicy {
            rendered_chat_prompt: &rendered_chat_prompt,
            prompt_token_limit: Some(request.max_prompt_tokens),
            generation_step_limit: request.max_new_tokens,
        },
    )?;
    let prompt_token_count = execution.prompt_token_ids.len();
    let generated_utf8_complete = execution.generated_text.is_some();
    Ok(PromptReceipt {
        schema_version: RECEIPT_SCHEMA_VERSION,
        model: execution.model,
        tokenizer: execution.tokenizer,
        dimensions: execution.dimensions,
        request: PromptRequestReceipt {
            user_message_blake3: blake3::hash(request.user_message.as_bytes())
                .to_hex()
                .to_string(),
            user_message_byte_count: request.user_message.len(),
            user_message: request.user_message,
            max_prompt_tokens: request.max_prompt_tokens,
            max_new_tokens: request.max_new_tokens,
            package_max_message_bytes: PROMPT_MAX_MESSAGE_BYTES,
            package_max_prompt_tokens: PROMPT_MAX_TOKEN_COUNT,
            package_max_new_tokens: PROMPT_MAX_NEW_TOKEN_COUNT,
        },
        rendered_chat_prompt_blake3: blake3::hash(rendered_chat_prompt.as_bytes())
            .to_hex()
            .to_string(),
        rendered_chat_prompt_byte_count: rendered_chat_prompt.len(),
        rendered_chat_prompt,
        prompt_token_count,
        prompt_token_ids: execution.prompt_token_ids,
        prompt_token_ids_blake3: execution.prompt_token_ids_blake3,
        generated_token_limit: execution.generation_step_limit,
        generated_token_ids: execution.generated_token_ids,
        generated_token_ids_blake3: execution.generated_token_ids_blake3,
        generated_bytes_hex: execution.generated_bytes_hex,
        generated_utf8_complete,
        generated_text: execution.generated_text,
        stop_reason: execution.stop_reason,
        arithmetic_precision: ARITHMETIC_PRECISION,
        steps: execution.steps,
        final_recurrent_states: execution.final_recurrent_states,
        maximum_oracle_state_deviation: execution.maximum_oracle_state_deviation,
        maximum_oracle_output_deviation: execution.maximum_oracle_output_deviation,
        maximum_replay_hidden_deviation: execution.maximum_replay_hidden_deviation,
        maximum_replay_state_deviation: execution.maximum_replay_state_deviation,
        minimum_retained_vs_reset_hidden_deviation: execution
            .minimum_retained_vs_reset_hidden_deviation,
        oracle_tolerance: ORACLE_TOLERANCE,
        replay_tolerance: REPLAY_TOLERANCE,
        non_claims: PROMPT_NON_CLAIMS.to_vec(),
    })
}

fn run_text_execution(
    checkpoint: &[u8],
    expected_model_blake3: &str,
    authority_inputs: TokenizerAuthorityInputs<'_>,
    policy: TextExecutionPolicy<'_>,
) -> Result<TextExecutionResult, String> {
    verify_checkpoint_digest(checkpoint, expected_model_blake3)?;
    let byte_count = u64::try_from(checkpoint.len())
        .map_err(|error| format!("checkpoint byte count does not fit u64: {error}"))?;
    if byte_count != MODEL_BYTE_COUNT {
        return Err(format!(
            "checkpoint byte count must be {MODEL_BYTE_COUNT}, found {byte_count}"
        ));
    }
    if policy.generation_step_limit == 0 {
        return Err("text execution requires a positive generation step limit".to_owned());
    }
    let (tokenizer, tokenizer_receipt) = validate_tokenizer_authority(authority_inputs)?;
    let prompt_token_ids = tokenizer.encode_wrapper_text(policy.rendered_chat_prompt)?;
    if prompt_token_ids.len() <= 1 {
        return Err("chat prompt must contain ordinary vocabulary tokens".to_owned());
    }
    if let Some(prompt_token_limit) = policy.prompt_token_limit {
        require_prompt_token_limit(prompt_token_ids.len(), prompt_token_limit)?;
    }

    let tensors = SafeTensors::deserialize(checkpoint)
        .map_err(|error| format!("failed to decode safetensors checkpoint: {error}"))?;
    let dimensions = Dimensions::reviewed();
    let weights = (0..MODEL_LAYER_COUNT)
        .map(|layer_index| load_layer(&tensors, dimensions, layer_index))
        .collect::<Result<Vec<_>, _>>()?;
    validate_model_weights(&weights)?;
    let embedding = tensors
        .tensor("model.embeddings.weight")
        .map_err(|error| format!("missing model.embeddings.weight: {error}"))?;
    let final_norm_weight = vector(&tensors, "model.norm.weight", dimensions.hidden_size)?;
    let final_norm_bias = vector(&tensors, "model.norm.bias", dimensions.hidden_size)?;
    let head_tensor = tensors
        .tensor("lm_head.weight")
        .map_err(|error| format!("missing lm_head.weight: {error}"))?;
    let head = matrix(
        &tensors,
        "lm_head.weight",
        VOCABULARY_SIZE,
        dimensions.hidden_size,
    )?;

    let mut execution = ModelExecutionState::zero(dimensions)?;
    let mut final_output = Vec::new();
    for token_id in &prompt_token_ids {
        let token_embedding = embedding_row(&embedding, *token_id, dimensions.hidden_size)?;
        (execution, final_output) = run_model_token(&weights, &token_embedding, execution)?;
    }
    ensure_oracle_tolerance(&execution, "chat prompt")?;
    let prompt_evaluation = evaluate_head(
        &final_output,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
        dimensions,
    )?;
    let prompt_states = execution.flattened_matrices();
    let (prompt_replay_execution, prompt_replay_output) =
        replay_input_ids(&weights, &embedding, &prompt_token_ids, dimensions)?;
    let prompt_replay_evaluation = evaluate_head(
        &prompt_replay_output,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
        dimensions,
    )?;
    let prompt_replay_states = prompt_replay_execution.flattened_matrices();
    let prompt_hidden_deviation = max_abs_difference(
        &prompt_evaluation.final_hidden,
        &prompt_replay_evaluation.final_hidden,
    )?;
    let prompt_state_deviation = max_abs_difference(&prompt_states, &prompt_replay_states)?;
    require_replay_tolerance(prompt_hidden_deviation, "prompt final hidden", 0)?;
    require_replay_tolerance(prompt_state_deviation, "prompt recurrent state", 0)?;
    let last_prompt_id = *prompt_token_ids
        .last()
        .ok_or_else(|| "chat prompt token IDs are empty".to_owned())?;
    let (_, prompt_reset_output) =
        replay_input_ids(&weights, &embedding, &[last_prompt_id], dimensions)?;
    let prompt_reset_evaluation = evaluate_head(
        &prompt_reset_output,
        &final_norm_weight,
        &final_norm_bias,
        &head,
        &head_tensor,
        dimensions,
    )?;
    let prompt_retained_vs_reset = max_abs_difference(
        &prompt_evaluation.final_hidden,
        &prompt_reset_evaluation.final_hidden,
    )?;
    require_state_carry_divergence(prompt_retained_vs_reset, 0)?;

    let mut processed_input_ids = prompt_token_ids.clone();
    let mut generated_token_ids = Vec::with_capacity(policy.generation_step_limit);
    let mut generated_bytes = Vec::new();
    let mut steps = Vec::with_capacity(policy.generation_step_limit);
    let mut maximum_replay_hidden_deviation = prompt_hidden_deviation;
    let mut maximum_replay_state_deviation = prompt_state_deviation;
    let mut minimum_retained_vs_reset_hidden_deviation = prompt_retained_vs_reset;
    let mut stop_reason = "generation_step_limit";

    for step_index in 0..policy.generation_step_limit {
        let selection = evaluate_head(
            &final_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let generated = selection.top_two.first;
        let runner_up = selection.top_two.second;
        let greedy_margin = generated.logit - runner_up.logit;
        if !greedy_margin.is_finite() || greedy_margin < 0.0 {
            return Err(format!(
                "text generation step {step_index} has invalid greedy margin {greedy_margin}"
            ));
        }
        generated_token_ids.push(generated.token_id);
        let generation_eos_selected = generated.token_id == GENERATION_CONFIG_EOS_TOKEN_ID;
        if generation_eos_selected {
            stop_reason = "generation_config_eos";
            steps.push(TextGenerationStepReceipt {
                step_index,
                generated_token_id: generated.token_id,
                generated_logit: generated.logit,
                runner_up_token_id: runner_up.token_id,
                runner_up_logit: runner_up.logit,
                greedy_margin,
                generated_token_bytes_hex: String::new(),
                generation_eos_selected,
                post_token_final_hidden: None,
                post_token_recurrent_states: None,
                incremental_replay_hidden_deviation: None,
                incremental_replay_state_deviation: None,
                retained_vs_reset_hidden_deviation: None,
                head_oracle_logit_deviation: selection.head_oracle_logit_deviation,
            });
            break;
        }

        let token_bytes = tokenizer.decode_wrapper_bytes(&[generated.token_id])?;
        generated_bytes.extend_from_slice(&token_bytes);
        let token_embedding =
            embedding_row(&embedding, generated.token_id, dimensions.hidden_size)?;
        (execution, final_output) = run_model_token(&weights, &token_embedding, execution)?;
        processed_input_ids.push(generated.token_id);
        ensure_oracle_tolerance(&execution, "generated token")?;
        let post_evaluation = evaluate_head(
            &final_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let incremental_states = execution.flattened_matrices();
        let (replay_execution, replay_output) =
            replay_input_ids(&weights, &embedding, &processed_input_ids, dimensions)?;
        ensure_oracle_tolerance(&replay_execution, "text replay")?;
        let replay_evaluation = evaluate_head(
            &replay_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let replay_states = replay_execution.flattened_matrices();
        let hidden_deviation = max_abs_difference(
            &post_evaluation.final_hidden,
            &replay_evaluation.final_hidden,
        )?;
        let state_deviation = max_abs_difference(&incremental_states, &replay_states)?;
        require_replay_tolerance(hidden_deviation, "text final hidden", step_index)?;
        require_replay_tolerance(state_deviation, "text recurrent state", step_index)?;
        let (_, reset_output) =
            replay_input_ids(&weights, &embedding, &[generated.token_id], dimensions)?;
        let reset_evaluation = evaluate_head(
            &reset_output,
            &final_norm_weight,
            &final_norm_bias,
            &head,
            &head_tensor,
            dimensions,
        )?;
        let retained_vs_reset_hidden_deviation = max_abs_difference(
            &post_evaluation.final_hidden,
            &reset_evaluation.final_hidden,
        )?;
        require_state_carry_divergence(retained_vs_reset_hidden_deviation, step_index)?;
        maximum_replay_hidden_deviation = maximum_replay_hidden_deviation.max(hidden_deviation);
        maximum_replay_state_deviation = maximum_replay_state_deviation.max(state_deviation);
        minimum_retained_vs_reset_hidden_deviation =
            minimum_retained_vs_reset_hidden_deviation.min(retained_vs_reset_hidden_deviation);
        steps.push(TextGenerationStepReceipt {
            step_index,
            generated_token_id: generated.token_id,
            generated_logit: generated.logit,
            runner_up_token_id: runner_up.token_id,
            runner_up_logit: runner_up.logit,
            greedy_margin,
            generated_token_bytes_hex: encode_hex(&token_bytes),
            generation_eos_selected,
            post_token_final_hidden: Some(numeric_receipt(&post_evaluation.final_hidden)?),
            post_token_recurrent_states: Some(numeric_receipt(&incremental_states)?),
            incremental_replay_hidden_deviation: Some(hidden_deviation),
            incremental_replay_state_deviation: Some(state_deviation),
            retained_vs_reset_hidden_deviation: Some(retained_vs_reset_hidden_deviation),
            head_oracle_logit_deviation: selection.head_oracle_logit_deviation,
        });
    }

    let generated_text = decode_complete_utf8(&generated_bytes);
    let maximum_oracle_state_deviation = execution
        .maximum_state_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    let maximum_oracle_output_deviation = execution
        .maximum_output_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    let final_recurrent_states = execution.flattened_matrices();

    Ok(TextExecutionResult {
        model: ModelReceipt {
            model_id: MODEL_ID,
            revision: MODEL_REVISION,
            sha256_sri: MODEL_SHA256_SRI,
            blake3: blake3::hash(checkpoint).to_hex().to_string(),
            byte_count,
        },
        tokenizer: tokenizer_receipt,
        dimensions,
        prompt_token_ids_blake3: fingerprint_token_ids(&prompt_token_ids)?,
        prompt_token_ids,
        generation_step_limit: policy.generation_step_limit,
        generated_token_ids_blake3: fingerprint_token_ids(&generated_token_ids)?,
        generated_token_ids,
        generated_bytes_hex: encode_hex(&generated_bytes),
        generated_text,
        stop_reason,
        steps,
        final_recurrent_states: numeric_receipt(&final_recurrent_states)?,
        maximum_oracle_state_deviation,
        maximum_oracle_output_deviation,
        maximum_replay_hidden_deviation,
        maximum_replay_state_deviation,
        minimum_retained_vs_reset_hidden_deviation,
    })
}

fn require_prompt_token_limit(actual: usize, limit: usize) -> Result<(), String> {
    if actual > limit {
        return Err(format!(
            "rendered chat prompt has {actual} tokens, exceeding caller limit {limit}"
        ));
    }
    Ok(())
}

fn decode_complete_utf8(bytes: &[u8]) -> Option<String> {
    String::from_utf8(bytes.to_vec()).ok()
}

fn encode_hex(bytes: &[u8]) -> String {
    use std::fmt::Write as _;

    let output_capacity = bytes
        .len()
        .checked_mul(HEX_CHARACTERS_PER_BYTE)
        .unwrap_or_default();
    let mut output = String::with_capacity(output_capacity);
    for byte in bytes {
        let _ = write!(&mut output, "{byte:02x}");
    }
    output
}

fn replay_input_ids(
    weights: &[LayerWeights],
    embedding: &TensorView<'_>,
    input_ids: &[usize],
    dimensions: Dimensions,
) -> Result<(ModelExecutionState, Vec<f32>), String> {
    if input_ids.is_empty() {
        return Err("replay requires at least one input token".to_owned());
    }
    let mut execution = ModelExecutionState::zero(dimensions)?;
    let mut final_output = Vec::new();
    for input_id in input_ids {
        let token_embedding = embedding_row(embedding, *input_id, dimensions.hidden_size)?;
        (execution, final_output) = run_model_token(weights, &token_embedding, execution)?;
    }
    Ok((execution, final_output))
}

fn evaluate_head(
    final_output: &[f32],
    final_norm_weight: &[f32],
    final_norm_bias: &[f32],
    head: &Matrix,
    head_tensor: &TensorView<'_>,
    dimensions: Dimensions,
) -> Result<HeadEvaluation, String> {
    let final_hidden = layer_norm(
        final_output,
        final_norm_weight,
        final_norm_bias,
        LAYER_NORM_EPSILON,
    )?;
    let logits = matvec(head, &final_hidden)?;
    let top_two = rank_top_two(
        logits
            .iter()
            .copied()
            .enumerate()
            .map(|(token_id, logit)| RankedLogit { token_id, logit }),
    )?;
    let oracle_top = direct_bf16_head_top_two(head_tensor, &final_hidden, dimensions.hidden_size)?;
    if top_two.first.token_id != oracle_top.first.token_id
        || top_two.second.token_id != oracle_top.second.token_id
    {
        return Err(format!(
            "LM-head ranking mismatch: production [{}, {}], direct oracle [{}, {}]",
            top_two.first.token_id,
            top_two.second.token_id,
            oracle_top.first.token_id,
            oracle_top.second.token_id
        ));
    }
    let head_oracle_logit_deviation = (top_two.first.logit - oracle_top.first.logit)
        .abs()
        .max((top_two.second.logit - oracle_top.second.logit).abs());
    if head_oracle_logit_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "LM-head oracle logit deviation {head_oracle_logit_deviation} exceeds tolerance {ORACLE_TOLERANCE}"
        ));
    }
    Ok(HeadEvaluation {
        final_hidden,
        logits,
        top_two,
        head_oracle_logit_deviation,
    })
}

fn ensure_oracle_tolerance(execution: &ModelExecutionState, path_name: &str) -> Result<(), String> {
    let state_deviation = execution
        .maximum_state_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    let output_deviation = execution
        .maximum_output_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    if state_deviation > ORACLE_TOLERANCE || output_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "{path_name} recurrence deviations state={state_deviation} output={output_deviation} exceed {ORACLE_TOLERANCE}"
        ));
    }
    Ok(())
}

fn require_replay_tolerance(
    deviation: f32,
    artifact_name: &str,
    step_index: usize,
) -> Result<(), String> {
    if !deviation.is_finite() || deviation > REPLAY_TOLERANCE {
        return Err(format!(
            "decode step {step_index} {artifact_name} replay deviation {deviation} exceeds {REPLAY_TOLERANCE}"
        ));
    }
    Ok(())
}

fn require_state_carry_divergence(deviation: f32, step_index: usize) -> Result<(), String> {
    if !deviation.is_finite() || deviation <= STATE_CARRY_DIVERGENCE_FLOOR {
        return Err(format!(
            "decode step {step_index} retained/reset hidden deviation {deviation} must exceed {STATE_CARRY_DIVERGENCE_FLOOR}"
        ));
    }
    Ok(())
}

fn validate_decode_chain(
    processed_input_ids: &[usize],
    generated_token_ids: &[usize],
) -> Result<(), String> {
    if processed_input_ids.len() != DECODE_STEP_COUNT
        || generated_token_ids.len() != DECODE_STEP_COUNT
    {
        return Err(format!(
            "decode chain requires {DECODE_STEP_COUNT} processed and generated tokens"
        ));
    }
    if processed_input_ids.first().copied() != Some(MODEL_CONFIG_BOS_TOKEN_ID) {
        return Err(format!(
            "decode chain must start with model-config BOS token {MODEL_CONFIG_BOS_TOKEN_ID}"
        ));
    }
    for step_index in 1..DECODE_STEP_COUNT {
        if processed_input_ids[step_index] != generated_token_ids[step_index - 1] {
            return Err(format!(
                "decode input at step {step_index} does not equal the prior generated token"
            ));
        }
    }
    Ok(())
}

pub fn verify_checkpoint_digest(checkpoint: &[u8], expected: &str) -> Result<(), String> {
    validate_blake3_hex(expected)?;
    let actual = blake3::hash(checkpoint).to_hex().to_string();
    if actual != expected {
        return Err(format!(
            "checkpoint BLAKE3 mismatch: expected {expected}, found {actual}"
        ));
    }
    Ok(())
}

fn validate_blake3_hex(digest: &str) -> Result<(), String> {
    if digest.len() != EXPECTED_DIGEST_HEX_LENGTH
        || !digest
            .chars()
            .all(|character| character.is_ascii_hexdigit() && !character.is_ascii_uppercase())
    {
        return Err(format!(
            "BLAKE3 digest must contain {EXPECTED_DIGEST_HEX_LENGTH} lowercase hexadecimal characters in radix {HEX_RADIX}"
        ));
    }
    Ok(())
}

fn load_layer_zero(
    tensors: &SafeTensors<'_>,
    dimensions: Dimensions,
) -> Result<LayerWeights, String> {
    load_layer(tensors, dimensions, LAYER_INDEX)
}

fn load_layer(
    tensors: &SafeTensors<'_>,
    dimensions: Dimensions,
    layer_index: usize,
) -> Result<LayerWeights, String> {
    dimensions.validate()?;
    if layer_index >= MODEL_LAYER_COUNT {
        return Err(format!(
            "layer index {layer_index} exceeds model layer count {MODEL_LAYER_COUNT}"
        ));
    }
    let hidden = dimensions.hidden_size;
    let intermediate = dimensions.intermediate_size;
    let head_count = dimensions.head_count;
    let head_size = dimensions.head_size;
    let name = |suffix: &str| format!("model.layers.{layer_index}.{suffix}");
    let (pre_norm_weight, pre_norm_bias) = if layer_index == LAYER_INDEX {
        (
            Some(vector(tensors, &name("pre_norm.weight"), hidden)?),
            Some(vector(tensors, &name("pre_norm.bias"), hidden)?),
        )
    } else {
        (None, None)
    };
    let (value_down, value_up, value_bias) = if layer_index == LAYER_INDEX {
        (None, None, None)
    } else {
        (
            Some(matrix(
                tensors,
                &name("attn.v_lora.lora.0.weight"),
                VALUE_RANK,
                hidden,
            )?),
            Some(matrix(
                tensors,
                &name("attn.v_lora.lora.2.weight"),
                hidden,
                VALUE_RANK,
            )?),
            Some(vector(tensors, &name("attn.v_lora.lora.2.bias"), hidden)?),
        )
    };
    Ok(LayerWeights {
        layer_index,
        dimensions,
        pre_norm_weight,
        pre_norm_bias,
        attn_norm_weight: vector(tensors, &name("attn_norm.weight"), hidden)?,
        attn_norm_bias: vector(tensors, &name("attn_norm.bias"), hidden)?,
        x_r: flexible_vector(tensors, &name("attn.x_r"), hidden)?,
        x_w: flexible_vector(tensors, &name("attn.x_w"), hidden)?,
        x_k: flexible_vector(tensors, &name("attn.x_k"), hidden)?,
        x_v: flexible_vector(tensors, &name("attn.x_v"), hidden)?,
        x_a: flexible_vector(tensors, &name("attn.x_a"), hidden)?,
        x_g: flexible_vector(tensors, &name("attn.x_g"), hidden)?,
        r_projection: matrix(tensors, &name("attn.r_proj.weight"), hidden, hidden)?,
        k_projection: matrix(tensors, &name("attn.k_proj.weight"), hidden, hidden)?,
        v_projection: matrix(tensors, &name("attn.v_proj.weight"), hidden, hidden)?,
        output_projection: matrix(tensors, &name("attn.o_proj.weight"), hidden, hidden)?,
        w_down: matrix(
            tensors,
            &name("attn.w_lora.lora.0.weight"),
            DECAY_RANK,
            hidden,
        )?,
        w_up: matrix(
            tensors,
            &name("attn.w_lora.lora.2.weight"),
            hidden,
            DECAY_RANK,
        )?,
        w_bias: vector(tensors, &name("attn.w_lora.lora.2.bias"), hidden)?,
        a_down: matrix(tensors, &name("attn.a_lora.lora.0.weight"), A_RANK, hidden)?,
        a_up: matrix(tensors, &name("attn.a_lora.lora.2.weight"), hidden, A_RANK)?,
        a_bias: vector(tensors, &name("attn.a_lora.lora.2.bias"), hidden)?,
        gate_down: matrix(
            tensors,
            &name("attn.g_lora.lora.0.weight"),
            GATE_RANK,
            hidden,
        )?,
        gate_up: matrix(
            tensors,
            &name("attn.g_lora.lora.2.weight"),
            hidden,
            GATE_RANK,
        )?,
        value_down,
        value_up,
        value_bias,
        k_k: vector(tensors, &name("attn.k_k"), hidden)?,
        k_a: vector(tensors, &name("attn.k_a"), hidden)?,
        r_k: shaped_vector(tensors, &name("attn.r_k"), &[head_count, head_size])?,
        group_norm_weight: vector(tensors, &name("attn.g_norm.weight"), hidden)?,
        group_norm_bias: vector(tensors, &name("attn.g_norm.bias"), hidden)?,
        ffn_norm_weight: vector(tensors, &name("ffn_norm.weight"), hidden)?,
        ffn_norm_bias: vector(tensors, &name("ffn_norm.bias"), hidden)?,
        ffn_x_k: vector(tensors, &name("ffn.x_k"), hidden)?,
        ffn_key: matrix(tensors, &name("ffn.key.weight"), intermediate, hidden)?,
        ffn_value: matrix(tensors, &name("ffn.value.weight"), hidden, intermediate)?,
    })
}

fn vector(tensors: &SafeTensors<'_>, name: &str, length: usize) -> Result<Vec<f32>, String> {
    shaped_vector(tensors, name, &[length])
}

fn flexible_vector(
    tensors: &SafeTensors<'_>,
    name: &str,
    length: usize,
) -> Result<Vec<f32>, String> {
    let tensor = tensors
        .tensor(name)
        .map_err(|error| format!("missing {name}: {error}"))?;
    let accepted = tensor.shape() == [length] || tensor.shape() == [1, 1, length];
    if !accepted {
        return Err(format!(
            "{name} must have shape [{length}] or [1, 1, {length}], found {:?}",
            tensor.shape()
        ));
    }
    decode_bf16(&tensor, name)
}

fn shaped_vector(
    tensors: &SafeTensors<'_>,
    name: &str,
    shape: &[usize],
) -> Result<Vec<f32>, String> {
    let tensor = tensors
        .tensor(name)
        .map_err(|error| format!("missing {name}: {error}"))?;
    require_shape(&tensor, name, shape)?;
    decode_bf16(&tensor, name)
}

fn matrix(
    tensors: &SafeTensors<'_>,
    name: &str,
    rows: usize,
    columns: usize,
) -> Result<Matrix, String> {
    let values = shaped_vector(tensors, name, &[rows, columns])?;
    Matrix::new(rows, columns, values)
}

fn embedding_row(
    tensor: &TensorView<'_>,
    row: usize,
    hidden_size: usize,
) -> Result<Vec<f32>, String> {
    require_dtype(tensor, "model.embeddings.weight", Dtype::BF16)?;
    require_shape(
        tensor,
        "model.embeddings.weight",
        &[VOCABULARY_SIZE, hidden_size],
    )?;
    if row >= VOCABULARY_SIZE {
        return Err(format!(
            "embedding row {row} exceeds vocabulary size {VOCABULARY_SIZE}"
        ));
    }
    let row_bytes = hidden_size
        .checked_mul(BF16_BYTE_WIDTH)
        .ok_or_else(|| "embedding row byte count overflows usize".to_owned())?;
    let start = row
        .checked_mul(row_bytes)
        .ok_or_else(|| "embedding row offset overflows usize".to_owned())?;
    let end = start
        .checked_add(row_bytes)
        .ok_or_else(|| "embedding row end overflows usize".to_owned())?;
    let bytes = tensor
        .data()
        .get(start..end)
        .ok_or_else(|| format!("embedding row {row} is outside tensor data"))?;
    decode_bf16_bytes(bytes, "model.embeddings.weight row")
}

fn direct_bf16_head_top_two(
    tensor: &TensorView<'_>,
    input: &[f32],
    hidden_size: usize,
) -> Result<TopTwo, String> {
    require_dtype(tensor, "lm_head.weight", Dtype::BF16)?;
    require_shape(tensor, "lm_head.weight", &[VOCABULARY_SIZE, hidden_size])?;
    direct_bf16_head_top_two_bytes(tensor.data(), input, hidden_size)
}

fn direct_bf16_head_top_two_bytes(
    head_bytes: &[u8],
    input: &[f32],
    hidden_size: usize,
) -> Result<TopTwo, String> {
    require_length(input, hidden_size, "direct head input")?;
    require_finite(input, "direct head input")?;
    let row_bytes = hidden_size
        .checked_mul(BF16_BYTE_WIDTH)
        .ok_or_else(|| "LM-head row byte count overflows usize".to_owned())?;
    let expected_bytes = VOCABULARY_SIZE
        .checked_mul(row_bytes)
        .ok_or_else(|| "LM-head byte count overflows usize".to_owned())?;
    if head_bytes.len() != expected_bytes {
        return Err(format!(
            "LM-head byte count mismatch: expected {expected_bytes}, found {}",
            head_bytes.len()
        ));
    }
    let ranked = (0..VOCABULARY_SIZE).map(|token_id| {
        let start = token_id
            .checked_mul(row_bytes)
            .ok_or_else(|| "LM-head row offset overflows usize".to_owned())?;
        let end = start
            .checked_add(row_bytes)
            .ok_or_else(|| "LM-head row end overflows usize".to_owned())?;
        let bytes = head_bytes
            .get(start..end)
            .ok_or_else(|| format!("LM-head row {token_id} is outside tensor data"))?;
        let mut logit = 0.0_f32;
        for (column, chunk) in bytes.chunks_exact(BF16_BYTE_WIDTH).enumerate() {
            let weight = bf16::from_bits(u16::from_le_bytes([chunk[0], chunk[1]])).to_f32();
            logit += weight * input[column];
        }
        if !logit.is_finite() {
            return Err(format!(
                "LM-head row {token_id} produced a non-finite logit"
            ));
        }
        Ok(RankedLogit { token_id, logit })
    });
    rank_top_two_results(ranked)
}

fn rank_top_two<I>(ranked: I) -> Result<TopTwo, String>
where
    I: IntoIterator<Item = RankedLogit>,
{
    rank_top_two_results(ranked.into_iter().map(Ok::<RankedLogit, String>))
}

fn rank_top_two_results<I>(ranked: I) -> Result<TopTwo, String>
where
    I: IntoIterator<Item = Result<RankedLogit, String>>,
{
    let mut first = None;
    let mut second = None;
    for candidate in ranked {
        let candidate = candidate?;
        if !candidate.logit.is_finite() {
            return Err(format!(
                "token {} has a non-finite logit",
                candidate.token_id
            ));
        }
        match first {
            None => first = Some(candidate),
            Some(current_first) if ranked_before(candidate, current_first) => {
                second = first;
                first = Some(candidate);
            }
            Some(_) => match second {
                None => second = Some(candidate),
                Some(current_second) if ranked_before(candidate, current_second) => {
                    second = Some(candidate);
                }
                Some(_) => {}
            },
        }
    }
    Ok(TopTwo {
        first: first.ok_or_else(|| "top-two ranking requires at least two logits".to_owned())?,
        second: second.ok_or_else(|| "top-two ranking requires at least two logits".to_owned())?,
    })
}

fn ranked_before(candidate: RankedLogit, current: RankedLogit) -> bool {
    candidate.logit > current.logit
        || (candidate.logit == current.logit && candidate.token_id < current.token_id)
}

fn require_shape(tensor: &TensorView<'_>, name: &str, expected: &[usize]) -> Result<(), String> {
    if tensor.shape() != expected {
        return Err(format!(
            "{name} must have shape {expected:?}, found {:?}",
            tensor.shape()
        ));
    }
    Ok(())
}

fn require_dtype(tensor: &TensorView<'_>, name: &str, expected: Dtype) -> Result<(), String> {
    if tensor.dtype() != expected {
        return Err(format!(
            "{name} must have dtype {expected:?}, found {:?}",
            tensor.dtype()
        ));
    }
    Ok(())
}

fn decode_bf16(tensor: &TensorView<'_>, name: &str) -> Result<Vec<f32>, String> {
    require_dtype(tensor, name, Dtype::BF16)?;
    decode_bf16_bytes(tensor.data(), name)
}

fn decode_bf16_bytes(bytes: &[u8], name: &str) -> Result<Vec<f32>, String> {
    if !bytes.len().is_multiple_of(BF16_BYTE_WIDTH) {
        return Err(format!("{name} BF16 byte count must be even"));
    }
    let values = bytes
        .chunks_exact(BF16_BYTE_WIDTH)
        .map(|chunk| bf16::from_bits(u16::from_le_bytes([chunk[0], chunk[1]])).to_f32())
        .collect::<Vec<_>>();
    require_finite(&values, name)?;
    Ok(values)
}

fn checked_shape_elements(shape: &[usize], name: &str) -> Result<usize, String> {
    if shape.is_empty() || shape.contains(&0) {
        return Err(format!("{name} logical shape dimensions must be positive"));
    }
    shape.iter().try_fold(1_usize, |elements, dimension| {
        elements
            .checked_mul(*dimension)
            .ok_or_else(|| format!("{name} logical shape element count overflows usize"))
    })
}

fn encode_bf16_artifact(
    name: &'static str,
    logical_shape: &[usize],
    values: &[f32],
) -> Result<EncodedBf16Artifact, String> {
    let expected_elements = checked_shape_elements(logical_shape, name)?;
    require_length(values, expected_elements, name)?;
    require_finite(values, name)?;
    let byte_count = values
        .len()
        .checked_mul(BF16_BYTE_WIDTH)
        .ok_or_else(|| format!("{name} BF16 byte count overflows usize"))?;
    let mut bytes = Vec::with_capacity(byte_count);
    for value in values {
        bytes.extend_from_slice(&bf16::from_f32(*value).to_bits().to_le_bytes());
    }
    let receipt = Bf16ArtifactReceipt {
        name,
        logical_shape: logical_shape.to_vec(),
        element_count: values.len(),
        byte_count,
        blake3: blake3::hash(&bytes).to_hex().to_string(),
        bytes_hex: encode_hex(&bytes),
    };
    let decoded = validate_bf16_artifact(&receipt)?;
    if decoded.len() != values.len() {
        return Err(format!("{name} BF16 artifact round-trip length changed"));
    }
    Ok(EncodedBf16Artifact { receipt, bytes })
}

fn lowercase_hex_nibble(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + u8::try_from(HEX_ALPHA_DIGIT_OFFSET).ok()?),
        _ => None,
    }
}

fn decode_lowercase_hex(text: &str, name: &str) -> Result<Vec<u8>, String> {
    if !text.len().is_multiple_of(HEX_CHARACTERS_PER_BYTE) {
        return Err(format!(
            "{name} hexadecimal byte string must have even length"
        ));
    }
    let mut bytes = Vec::with_capacity(text.len() / HEX_CHARACTERS_PER_BYTE);
    for pair in text.as_bytes().chunks_exact(HEX_CHARACTERS_PER_BYTE) {
        let high = lowercase_hex_nibble(pair[0])
            .ok_or_else(|| format!("{name} contains non-lowercase-hexadecimal data"))?;
        let low = lowercase_hex_nibble(pair[1])
            .ok_or_else(|| format!("{name} contains non-lowercase-hexadecimal data"))?;
        bytes.push(high * u8::try_from(HEX_RADIX).map_err(|error| error.to_string())? + low);
    }
    Ok(bytes)
}

fn validate_bf16_artifact(artifact: &Bf16ArtifactReceipt) -> Result<Vec<f32>, String> {
    let expected_elements = checked_shape_elements(&artifact.logical_shape, artifact.name)?;
    if artifact.element_count != expected_elements {
        return Err(format!(
            "{} BF16 artifact shape requires {expected_elements} elements, found {}",
            artifact.name, artifact.element_count
        ));
    }
    let expected_bytes = expected_elements
        .checked_mul(BF16_BYTE_WIDTH)
        .ok_or_else(|| format!("{} BF16 byte count overflows usize", artifact.name))?;
    if artifact.byte_count != expected_bytes {
        return Err(format!(
            "{} BF16 artifact requires {expected_bytes} bytes, found {}",
            artifact.name, artifact.byte_count
        ));
    }
    let bytes = decode_lowercase_hex(&artifact.bytes_hex, artifact.name)?;
    if bytes.len() != artifact.byte_count {
        return Err(format!(
            "{} BF16 hexadecimal data contains {} bytes, expected {}",
            artifact.name,
            bytes.len(),
            artifact.byte_count
        ));
    }
    let actual_blake3 = blake3::hash(&bytes).to_hex().to_string();
    if actual_blake3 != artifact.blake3 {
        return Err(format!(
            "{} BF16 artifact BLAKE3 mismatch: expected {}, found {actual_blake3}",
            artifact.name, artifact.blake3
        ));
    }
    decode_bf16_bytes(&bytes, artifact.name)
}

fn expected_ttwkv7_artifact_shape(name: &str) -> Option<&'static [usize]> {
    match name {
        "a" | "w" | "k" | "v" | "r" | "b" | "expected_output" => {
            Some(&TTWKV7_BOUNDARY_VECTOR_SHAPE)
        }
        "pre_state" | "expected_post_state" => Some(&TTWKV7_BOUNDARY_STATE_SHAPE),
        _ => None,
    }
}

fn ordered_artifact_blake3(artifacts: &[Bf16ArtifactReceipt]) -> Result<String, String> {
    if artifacts.len() != TTWKV7_BOUNDARY_ARTIFACT_COUNT {
        return Err(format!(
            "ttWKV7 boundary requires {TTWKV7_BOUNDARY_ARTIFACT_COUNT} ordered artifacts, found {}",
            artifacts.len()
        ));
    }
    let mut hasher = blake3::Hasher::new();
    hasher.update(TTWKV7_BOUNDARY_HASH_DOMAIN);
    for (expected_name, artifact) in TTWKV7_BOUNDARY_ARTIFACT_ORDER.iter().zip(artifacts) {
        if artifact.name != *expected_name {
            return Err(format!(
                "ttWKV7 boundary artifact order expected {expected_name}, found {}",
                artifact.name
            ));
        }
        let expected_shape = expected_ttwkv7_artifact_shape(artifact.name)
            .ok_or_else(|| format!("unknown ttWKV7 boundary artifact {}", artifact.name))?;
        if artifact.logical_shape != expected_shape {
            return Err(format!(
                "{} logical shape must be {expected_shape:?}, found {:?}",
                artifact.name, artifact.logical_shape
            ));
        }
        validate_bf16_artifact(artifact)?;
        let bytes = decode_lowercase_hex(&artifact.bytes_hex, artifact.name)?;
        if blake3::hash(&bytes).to_hex().as_str() != artifact.blake3 {
            return Err(format!("{} changed before combined hashing", artifact.name));
        }
        let name_length = u64::try_from(artifact.name.len())
            .map_err(|error| format!("artifact name length does not fit u64: {error}"))?;
        let element_count = u64::try_from(artifact.element_count)
            .map_err(|error| format!("artifact element count does not fit u64: {error}"))?;
        let shape_rank = u64::try_from(artifact.logical_shape.len())
            .map_err(|error| format!("artifact shape rank does not fit u64: {error}"))?;
        hasher.update(&name_length.to_le_bytes());
        hasher.update(artifact.name.as_bytes());
        hasher.update(&shape_rank.to_le_bytes());
        for dimension in &artifact.logical_shape {
            let dimension = u64::try_from(*dimension)
                .map_err(|error| format!("artifact shape dimension does not fit u64: {error}"))?;
            hasher.update(&dimension.to_le_bytes());
        }
        hasher.update(&element_count.to_le_bytes());
        hasher.update(&bytes);
    }
    Ok(hasher.finalize().to_hex().to_string())
}

fn maximum_absolute_value(values: &[f32], name: &str) -> Result<f32, String> {
    require_finite(values, name)?;
    Ok(values.iter().copied().map(f32::abs).fold(0.0_f32, f32::max))
}

fn run_sequence(
    weights: &LayerWeights,
    embeddings: [&[f32]; TOKEN_COUNT],
) -> Result<SequenceResult, String> {
    let dimensions = weights.dimensions;
    let mut state = LayerState::zero(dimensions)?;
    let mut oracle_state = state.matrix.clone();
    let mut maximum_state_deviation = 0.0_f32;
    let mut maximum_output_deviation = 0.0_f32;
    let mut second_pre_state = None;
    let mut second_preparation = None;
    let mut second_residual = None;
    let mut second_ffn_previous = None;
    let mut second_raw_output = None;
    let mut final_output = Vec::new();

    for (token_index, embedding) in embeddings.into_iter().enumerate() {
        require_length(embedding, dimensions.hidden_size, "embedding")?;
        let pre_norm_weight = weights
            .pre_norm_weight
            .as_deref()
            .ok_or_else(|| "layer-zero pre-norm weight is missing".to_owned())?;
        let pre_norm_bias = weights
            .pre_norm_bias
            .as_deref()
            .ok_or_else(|| "layer-zero pre-norm bias is missing".to_owned())?;
        let residual = layer_norm(
            embedding,
            pre_norm_weight,
            pre_norm_bias,
            LAYER_NORM_EPSILON,
        )?;
        let attention_input = layer_norm(
            &residual,
            &weights.attn_norm_weight,
            &weights.attn_norm_bias,
            LAYER_NORM_EPSILON,
        )?;
        let is_second_token = token_index + 1 == TOKEN_COUNT;
        if is_second_token {
            second_pre_state = Some(state.matrix.clone());
            second_residual = Some(residual.clone());
            second_ffn_previous = Some(state.ffn_previous.clone());
        }
        let time = time_mix(
            weights,
            &attention_input,
            &state.attention_previous,
            &state.matrix,
            &oracle_state,
            None,
        )?;
        state.attention_previous.clone_from(&attention_input);
        maximum_state_deviation = maximum_state_deviation
            .max(max_abs_difference(&time.matrix_state, &time.oracle_state)?);
        state.matrix = time.matrix_state;
        oracle_state = time.oracle_state;
        maximum_output_deviation = maximum_output_deviation
            .max(max_abs_difference(&time.wkv_output, &time.oracle_output)?);
        let suffix =
            finish_layer_suffix(weights, &residual, &time.wkv_output, &state.ffn_previous)?;
        state.ffn_previous = suffix.ffn_input;
        final_output = suffix.final_output;
        if is_second_token {
            second_raw_output = Some(time.raw_wkv_output);
            second_preparation = Some(time.preparation);
        }
    }

    let second_pre_state =
        second_pre_state.ok_or_else(|| "second-token pre-state was not produced".to_owned())?;
    let second_preparation = second_preparation
        .ok_or_else(|| "second-token time-mix preparation was not produced".to_owned())?;
    let second_residual =
        second_residual.ok_or_else(|| "second-token residual was not produced".to_owned())?;
    let second_ffn_previous =
        second_ffn_previous.ok_or_else(|| "second-token FFN state was not produced".to_owned())?;
    let second_raw_output =
        second_raw_output.ok_or_else(|| "second-token raw output was not produced".to_owned())?;
    require_finite(&final_output, "final layer output")?;
    require_finite(&state.matrix, "final recurrent state")?;
    Ok(SequenceResult {
        final_output,
        final_state: state.matrix,
        final_attention_previous: state.attention_previous,
        final_ffn_previous: state.ffn_previous,
        second_pre_state,
        second_preparation,
        second_residual,
        second_ffn_previous,
        second_raw_output,
        maximum_state_deviation,
        maximum_output_deviation,
    })
}

fn finish_layer_suffix(
    weights: &LayerWeights,
    residual: &[f32],
    attention_output: &[f32],
    ffn_previous: &[f32],
) -> Result<LayerSuffixOutput, String> {
    let after_attention = add_vectors(residual, attention_output)?;
    let ffn_input = layer_norm(
        &after_attention,
        &weights.ffn_norm_weight,
        &weights.ffn_norm_bias,
        LAYER_NORM_EPSILON,
    )?;
    let ffn_output = channel_mix(weights, &ffn_input, ffn_previous)?;
    let final_output = add_vectors(&after_attention, &ffn_output)?;
    require_finite(&final_output, "layer suffix output")?;
    Ok(LayerSuffixOutput {
        ffn_input,
        final_output,
    })
}

fn run_model_sequence(
    weights: &[LayerWeights],
    embeddings: [&[f32]; TOKEN_COUNT],
) -> Result<ModelSequenceResult, String> {
    validate_model_weights(weights)?;
    let dimensions = Dimensions::reviewed();
    let mut execution = ModelExecutionState::zero(dimensions)?;
    let mut final_output = Vec::new();
    for embedding in embeddings {
        (execution, final_output) = run_model_token(weights, embedding, execution)?;
    }
    finish_model_execution(execution, final_output)
}

fn validate_model_weights(weights: &[LayerWeights]) -> Result<(), String> {
    if weights.len() != MODEL_LAYER_COUNT {
        return Err(format!(
            "full model requires {MODEL_LAYER_COUNT} layers, found {}",
            weights.len()
        ));
    }
    for (layer_index, layer) in weights.iter().enumerate() {
        if layer.layer_index != layer_index {
            return Err(format!(
                "layer slot {layer_index} contains weights for layer {}",
                layer.layer_index
            ));
        }
    }
    Ok(())
}

fn run_model_token(
    weights: &[LayerWeights],
    embedding: &[f32],
    execution: ModelExecutionState,
) -> Result<(ModelExecutionState, Vec<f32>), String> {
    let result = run_model_token_with_layer_zero_mode(
        weights,
        embedding,
        execution,
        LayerZeroWkvMode::SourceFp32,
    )?;
    Ok((result.execution, result.final_output))
}

fn run_model_token_with_layer_zero_mode(
    weights: &[LayerWeights],
    embedding: &[f32],
    mut execution: ModelExecutionState,
    layer_zero_mode: LayerZeroWkvMode<'_>,
) -> Result<ModelTokenExecution, String> {
    validate_model_weights(weights)?;
    let dimensions = Dimensions::reviewed();
    execution.validate(dimensions)?;
    require_length(embedding, dimensions.hidden_size, "model embedding")?;
    let mut hidden = embedding.to_vec();
    let mut value_anchor = None;
    let mut layer_outputs = Vec::with_capacity(MODEL_LAYER_COUNT);
    let mut layer_zero_pre_state = None;
    let mut layer_zero_raw_output = None;
    let mut layer_zero_post_state = None;
    for (layer_index, layer) in weights.iter().enumerate() {
        let residual = apply_pre_norm(layer, &hidden)?;
        let attention_input = layer_norm(
            &residual,
            &layer.attn_norm_weight,
            &layer.attn_norm_bias,
            LAYER_NORM_EPSILON,
        )?;
        let time = if layer_index == LAYER_INDEX {
            layer_zero_pre_state = Some(execution.layers[layer_index].matrix.clone());
            time_mix_layer_zero_mode(
                layer,
                &attention_input,
                &execution.layers[layer_index].attention_previous,
                &execution.layers[layer_index].matrix,
                &execution.oracle_matrices[layer_index],
                layer_zero_mode,
            )?
        } else {
            time_mix(
                layer,
                &attention_input,
                &execution.layers[layer_index].attention_previous,
                &execution.layers[layer_index].matrix,
                &execution.oracle_matrices[layer_index],
                value_anchor.as_deref(),
            )?
        };
        if layer_index == LAYER_INDEX {
            value_anchor = Some(time.preparation.projected_value.clone());
            layer_zero_raw_output = Some(time.raw_wkv_output.clone());
            layer_zero_post_state = Some(time.matrix_state.clone());
        }
        execution.layers[layer_index]
            .attention_previous
            .clone_from(&attention_input);
        let state_deviation = max_abs_difference(&time.matrix_state, &time.oracle_state)?;
        execution.maximum_state_deviations[layer_index] =
            execution.maximum_state_deviations[layer_index].max(state_deviation);
        let output_deviation = max_abs_difference(&time.wkv_output, &time.oracle_output)?;
        execution.maximum_output_deviations[layer_index] =
            execution.maximum_output_deviations[layer_index].max(output_deviation);
        execution.layers[layer_index].matrix = time.matrix_state;
        execution.oracle_matrices[layer_index] = time.oracle_state;

        let suffix = finish_layer_suffix(
            layer,
            &residual,
            &time.wkv_output,
            &execution.layers[layer_index].ffn_previous,
        )?;
        execution.layers[layer_index].ffn_previous = suffix.ffn_input;
        hidden = suffix.final_output;
        layer_outputs.push(hidden.clone());
    }
    if value_anchor.is_none() {
        return Err("layer zero did not establish v_first".to_owned());
    }
    require_finite(&hidden, "full-model token output")?;
    execution.validate(dimensions)?;
    Ok(ModelTokenExecution {
        execution,
        final_output: hidden,
        layer_outputs,
        layer_zero_pre_state: layer_zero_pre_state
            .ok_or_else(|| "layer zero did not record pre-state".to_owned())?,
        layer_zero_raw_output: layer_zero_raw_output
            .ok_or_else(|| "layer zero did not record raw WKV output".to_owned())?,
        layer_zero_post_state: layer_zero_post_state
            .ok_or_else(|| "layer zero did not record post-state".to_owned())?,
    })
}

fn quantize_wkv_inputs(inputs: &WkvInputs) -> Result<WkvInputs, String> {
    Ok(WkvInputs {
        r: quantize_bf16_values(&inputs.r, "BF16-boundary r")?,
        w: quantize_bf16_values(&inputs.w, "BF16-boundary w")?,
        k: quantize_bf16_values(&inputs.k, "BF16-boundary k")?,
        v: quantize_bf16_values(&inputs.v, "BF16-boundary v")?,
        a: quantize_bf16_values(&inputs.a, "BF16-boundary a")?,
        b: quantize_bf16_values(&inputs.b, "BF16-boundary b")?,
    })
}

fn quantize_bf16_values(values: &[f32], name: &str) -> Result<Vec<f32>, String> {
    require_finite(values, name)?;
    let quantized = values
        .iter()
        .map(|value| bf16::from_f32(*value).to_f32())
        .collect::<Vec<_>>();
    require_finite(&quantized, name)?;
    Ok(quantized)
}

fn time_mix_layer_zero_mode(
    weights: &LayerWeights,
    input: &[f32],
    previous: &[f32],
    state: &[f32],
    oracle_state: &[f32],
    mode: LayerZeroWkvMode<'_>,
) -> Result<TimeMixOutput, String> {
    if weights.layer_index != LAYER_INDEX {
        return Err(format!(
            "layer-zero WKV mode received layer {}",
            weights.layer_index
        ));
    }
    if matches!(mode, LayerZeroWkvMode::SourceFp32) {
        return time_mix(weights, input, previous, state, oracle_state, None);
    }

    let dimensions = weights.dimensions;
    let preparation = prepare_time_mix(weights, input, previous, None)?;
    let (matrix_state, raw_wkv_output) = match mode {
        LayerZeroWkvMode::SourceFp32 => {
            return Err("source FP32 layer-zero mode escaped the direct path".to_owned());
        }
        LayerZeroWkvMode::Bf16Cpu => {
            let consumed_inputs = quantize_wkv_inputs(&preparation.wkv_inputs)?;
            let consumed_state = quantize_bf16_values(state, "model layer-zero pre-state")?;
            let (next_state, raw_output) =
                wkv_step_matrix(&consumed_state, &consumed_inputs, dimensions)?;
            (
                quantize_bf16_values(&next_state, "model layer-zero post-state")?,
                quantize_bf16_values(&raw_output, "model layer-zero raw output")?,
            )
        }
        LayerZeroWkvMode::Observed {
            raw_output,
            post_state,
        } => {
            require_length(
                raw_output,
                dimensions.hidden_size,
                "observed model layer-zero raw output",
            )?;
            require_length(
                post_state,
                dimensions.head_count * dimensions.head_size * dimensions.head_size,
                "observed model layer-zero post-state",
            )?;
            require_finite(raw_output, "observed model layer-zero raw output")?;
            require_finite(post_state, "observed model layer-zero post-state")?;
            (post_state.to_vec(), raw_output.to_vec())
        }
    };
    let attention_output = finish_time_mix_attention(weights, &preparation, &raw_wkv_output)?;
    Ok(TimeMixOutput {
        preparation,
        raw_wkv_output,
        wkv_output: attention_output.clone(),
        oracle_output: attention_output,
        matrix_state: matrix_state.clone(),
        oracle_state: matrix_state,
    })
}

fn finish_model_execution(
    execution: ModelExecutionState,
    final_output: Vec<f32>,
) -> Result<ModelSequenceResult, String> {
    execution.validate(Dimensions::reviewed())?;
    require_finite(&final_output, "full-model final layer output")?;
    let recurrent_states = execution.flattened_matrices();
    require_finite(&recurrent_states, "full-model recurrent states")?;
    let layer_deviations = layer_deviation_receipts(&execution);
    let maximum_state_deviation = execution
        .maximum_state_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    let maximum_output_deviation = execution
        .maximum_output_deviations
        .iter()
        .copied()
        .fold(0.0_f32, f32::max);
    Ok(ModelSequenceResult {
        final_output,
        recurrent_states,
        layer_deviations,
        maximum_state_deviation,
        maximum_output_deviation,
    })
}

fn layer_deviation_receipts(execution: &ModelExecutionState) -> Vec<LayerDeviationReceipt> {
    execution
        .maximum_state_deviations
        .iter()
        .copied()
        .zip(execution.maximum_output_deviations.iter().copied())
        .enumerate()
        .map(
            |(layer_index, (maximum_state_deviation, maximum_output_deviation))| {
                LayerDeviationReceipt {
                    layer_index,
                    maximum_state_deviation,
                    maximum_output_deviation,
                }
            },
        )
        .collect()
}

fn apply_pre_norm(weights: &LayerWeights, input: &[f32]) -> Result<Vec<f32>, String> {
    match (
        weights.layer_index,
        weights.pre_norm_weight.as_deref(),
        weights.pre_norm_bias.as_deref(),
    ) {
        (LAYER_INDEX, Some(weight), Some(bias)) => {
            layer_norm(input, weight, bias, LAYER_NORM_EPSILON)
        }
        (LAYER_INDEX, _, _) => Err("layer zero requires pre-norm weight and bias".to_owned()),
        (_, None, None) => Ok(input.to_vec()),
        (_, _, _) => Err(format!(
            "layer {} must not contain layer-zero pre-norm tensors",
            weights.layer_index
        )),
    }
}

fn time_mix(
    weights: &LayerWeights,
    input: &[f32],
    previous: &[f32],
    state: &[f32],
    oracle_state: &[f32],
    value_anchor: Option<&[f32]>,
) -> Result<TimeMixOutput, String> {
    let dimensions = weights.dimensions;
    let preparation = prepare_time_mix(weights, input, previous, value_anchor)?;
    let (next_state, raw_output) = wkv_step_matrix(state, &preparation.wkv_inputs, dimensions)?;
    let (next_oracle_state, oracle_raw_output) =
        wkv_step_oracle(oracle_state, &preparation.wkv_inputs, dimensions)?;
    let attention_output = finish_time_mix_attention(weights, &preparation, &raw_output)?;
    let oracle_output = finish_time_mix_attention(weights, &preparation, &oracle_raw_output)?;
    let state_deviation = max_abs_difference(&next_state, &next_oracle_state)?;
    if state_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "time-mix recurrence state deviation {state_deviation} exceeds {ORACLE_TOLERANCE}"
        ));
    }

    Ok(TimeMixOutput {
        preparation,
        raw_wkv_output: raw_output,
        wkv_output: attention_output,
        oracle_output,
        matrix_state: next_state,
        oracle_state: next_oracle_state,
    })
}

fn prepare_time_mix(
    weights: &LayerWeights,
    input: &[f32],
    previous: &[f32],
    value_anchor: Option<&[f32]>,
) -> Result<TimeMixPreparation, String> {
    let dimensions = weights.dimensions;
    let x_r = mixed(input, previous, &weights.x_r)?;
    let x_w = mixed(input, previous, &weights.x_w)?;
    let x_k = mixed(input, previous, &weights.x_k)?;
    let x_v = mixed(input, previous, &weights.x_v)?;
    let x_a = mixed(input, previous, &weights.x_a)?;
    let x_g = mixed(input, previous, &weights.x_g)?;

    let r = matvec(&weights.r_projection, &x_r)?;
    let raw_k = matvec(&weights.k_projection, &x_k)?;
    let projected_value = matvec(&weights.v_projection, &x_v)?;
    let v = resolve_layer_value(weights, &x_v, &projected_value, value_anchor)?;

    let w_hidden = matvec(&weights.w_down, &x_w)?
        .into_iter()
        .map(f32::tanh)
        .collect::<Vec<_>>();
    let w_logits = add_vectors(&matvec(&weights.w_up, &w_hidden)?, &weights.w_bias)?;
    let w = w_logits
        .into_iter()
        .map(|value| (NEGATIVE_INVERSE_SQRT_E * sigmoid(value)).exp())
        .collect::<Vec<_>>();

    let a_hidden = matvec(&weights.a_down, &x_a)?;
    let a_logits = add_vectors(&matvec(&weights.a_up, &a_hidden)?, &weights.a_bias)?;
    let a_gate = a_logits.into_iter().map(sigmoid).collect::<Vec<_>>();

    let gate_hidden = matvec(&weights.gate_down, &x_g)?
        .into_iter()
        .map(sigmoid)
        .collect::<Vec<_>>();
    let gate = matvec(&weights.gate_up, &gate_hidden)?;

    let kk_unnormalized = multiply_vectors(&raw_k, &weights.k_k)?;
    let kk = normalize_heads(&kk_unnormalized, dimensions)?;
    let k = raw_k
        .iter()
        .zip(a_gate.iter())
        .zip(weights.k_a.iter())
        .map(|((&key, &gate_value), &scale)| key * (1.0 + (gate_value - 1.0) * scale))
        .collect::<Vec<_>>();
    let a = kk.iter().map(|value| -*value).collect::<Vec<_>>();
    let b = multiply_vectors(&kk, &a_gate)?;
    let wkv_inputs = WkvInputs { r, w, k, v, a, b };

    Ok(TimeMixPreparation {
        projected_value,
        wkv_inputs,
        gate,
    })
}

fn finish_time_mix_attention(
    weights: &LayerWeights,
    preparation: &TimeMixPreparation,
    raw_output: &[f32],
) -> Result<Vec<f32>, String> {
    let dimensions = weights.dimensions;
    require_length(raw_output, dimensions.hidden_size, "raw WKV output")?;
    require_finite(raw_output, "raw WKV output")?;
    let normalized = group_norm(
        raw_output,
        &weights.group_norm_weight,
        &weights.group_norm_bias,
        dimensions,
    )?;
    let corrected = gate_correction(
        &normalized,
        &preparation.wkv_inputs.r,
        &preparation.wkv_inputs.k,
        &weights.r_k,
        &preparation.wkv_inputs.v,
        &preparation.gate,
        dimensions,
    )?;
    let attention_output = matvec(&weights.output_projection, &corrected)?;
    require_finite(&attention_output, "attention output")?;
    Ok(attention_output)
}

fn resolve_layer_value(
    weights: &LayerWeights,
    mixed_value_input: &[f32],
    projected_value: &[f32],
    value_anchor: Option<&[f32]>,
) -> Result<Vec<f32>, String> {
    require_length(
        projected_value,
        weights.dimensions.hidden_size,
        "projected value",
    )?;
    if weights.layer_index == LAYER_INDEX {
        if value_anchor.is_some()
            || weights.value_down.is_some()
            || weights.value_up.is_some()
            || weights.value_bias.is_some()
        {
            return Err("layer zero must establish v_first without value LoRA".to_owned());
        }
        return Ok(projected_value.to_vec());
    }

    let anchor = value_anchor.ok_or_else(|| {
        format!(
            "layer {} requires the current token's layer-zero v_first",
            weights.layer_index
        )
    })?;
    let down = weights.value_down.as_ref().ok_or_else(|| {
        format!(
            "layer {} value LoRA down matrix is missing",
            weights.layer_index
        )
    })?;
    let up = weights.value_up.as_ref().ok_or_else(|| {
        format!(
            "layer {} value LoRA up matrix is missing",
            weights.layer_index
        )
    })?;
    let bias = weights
        .value_bias
        .as_deref()
        .ok_or_else(|| format!("layer {} value LoRA bias is missing", weights.layer_index))?;
    let hidden = matvec(down, mixed_value_input)?;
    let logits = add_vectors(&matvec(up, &hidden)?, bias)?;
    let gates = logits.into_iter().map(sigmoid).collect::<Vec<_>>();
    interpolate_values(projected_value, anchor, &gates)
}

fn interpolate_values(
    projected: &[f32],
    anchor: &[f32],
    gates: &[f32],
) -> Result<Vec<f32>, String> {
    require_same_lengths(projected, anchor, "value interpolation projected/anchor")?;
    require_same_lengths(projected, gates, "value interpolation projected/gates")?;
    require_finite(projected, "value interpolation projected")?;
    require_finite(anchor, "value interpolation anchor")?;
    require_finite(gates, "value interpolation gates")?;
    if gates.iter().any(|gate| !(0.0..=1.0).contains(gate)) {
        return Err("value interpolation gate must be in the inclusive range [0, 1]".to_owned());
    }
    let output = projected
        .iter()
        .zip(anchor.iter())
        .zip(gates.iter())
        .map(|((&value, &first), &gate)| value + gate * (first - value))
        .collect::<Vec<_>>();
    require_finite(&output, "value interpolation output")?;
    Ok(output)
}

fn channel_mix(
    weights: &LayerWeights,
    input: &[f32],
    previous: &[f32],
) -> Result<Vec<f32>, String> {
    let mixed_input = mixed(input, previous, &weights.ffn_x_k)?;
    let activated = matvec(&weights.ffn_key, &mixed_input)?
        .into_iter()
        .map(|value| {
            let relu = value.max(0.0);
            relu * relu
        })
        .collect::<Vec<_>>();
    let output = matvec(&weights.ffn_value, &activated)?;
    require_finite(&output, "channel-mix output")?;
    Ok(output)
}

fn wkv_step_matrix(
    state: &[f32],
    inputs: &WkvInputs,
    dimensions: Dimensions,
) -> Result<(Vec<f32>, Vec<f32>), String> {
    validate_wkv_shapes(state, inputs, dimensions)?;
    let mut next = vec![0.0_f32; state.len()];
    let mut output = vec![0.0_f32; dimensions.hidden_size];
    for head in 0..dimensions.head_count {
        let vector_base = head * dimensions.head_size;
        let matrix_base = head * dimensions.head_size * dimensions.head_size;
        let mut state_dot_a = vec![0.0_f32; dimensions.head_size];
        for (row, destination) in state_dot_a.iter_mut().enumerate() {
            let mut sum = 0.0_f32;
            for column in 0..dimensions.head_size {
                sum += state[matrix_base + row * dimensions.head_size + column]
                    * inputs.a[vector_base + column];
            }
            *destination = sum;
        }
        for (row, state_dot_a_row) in state_dot_a.iter().copied().enumerate() {
            for column in 0..dimensions.head_size {
                let vector_column = vector_base + column;
                let index = matrix_base + row * dimensions.head_size + column;
                next[index] = state[index] * inputs.w[vector_column]
                    + state_dot_a_row * inputs.b[vector_column]
                    + inputs.v[vector_base + row] * inputs.k[vector_column];
            }
        }
        for row in 0..dimensions.head_size {
            let mut sum = 0.0_f32;
            for column in 0..dimensions.head_size {
                sum += next[matrix_base + row * dimensions.head_size + column]
                    * inputs.r[vector_base + column];
            }
            output[vector_base + row] = sum;
        }
    }
    require_finite(&next, "matrix recurrence state")?;
    require_finite(&output, "matrix recurrence output")?;
    Ok((next, output))
}

fn wkv_step_oracle(
    state: &[f32],
    inputs: &WkvInputs,
    dimensions: Dimensions,
) -> Result<(Vec<f32>, Vec<f32>), String> {
    validate_wkv_shapes(state, inputs, dimensions)?;
    let mut next = vec![0.0_f32; state.len()];
    let mut output = vec![0.0_f32; dimensions.hidden_size];
    for head in 0..dimensions.head_count {
        let vector_base = head * dimensions.head_size;
        let matrix_base = head * dimensions.head_size * dimensions.head_size;
        for row in 0..dimensions.head_size {
            for column in 0..dimensions.head_size {
                let mut rank_update = 0.0_f32;
                for contracted in 0..dimensions.head_size {
                    rank_update += state[matrix_base + row * dimensions.head_size + contracted]
                        * inputs.a[vector_base + contracted]
                        * inputs.b[vector_base + column];
                }
                let index = matrix_base + row * dimensions.head_size + column;
                let decay = state[index] * inputs.w[vector_base + column];
                let outer = inputs.v[vector_base + row] * inputs.k[vector_base + column];
                next[index] = decay + rank_update + outer;
            }
            let mut readout = 0.0_f32;
            for column in 0..dimensions.head_size {
                readout += next[matrix_base + row * dimensions.head_size + column]
                    * inputs.r[vector_base + column];
            }
            output[vector_base + row] = readout;
        }
    }
    require_finite(&next, "oracle recurrence state")?;
    require_finite(&output, "oracle recurrence output")?;
    Ok((next, output))
}

fn validate_wkv_shapes(
    state: &[f32],
    inputs: &WkvInputs,
    dimensions: Dimensions,
) -> Result<(), String> {
    dimensions.validate()?;
    let state_elements = dimensions.head_count * dimensions.head_size * dimensions.head_size;
    require_length(state, state_elements, "WKV state")?;
    for (values, name) in [
        (&inputs.r, "r"),
        (&inputs.w, "w"),
        (&inputs.k, "k"),
        (&inputs.v, "v"),
        (&inputs.a, "a"),
        (&inputs.b, "b"),
    ] {
        require_length(values, dimensions.hidden_size, name)?;
        require_finite(values, name)?;
    }
    require_finite(state, "WKV state")?;
    Ok(())
}

fn matvec(matrix: &Matrix, input: &[f32]) -> Result<Vec<f32>, String> {
    require_length(input, matrix.columns, "matrix-vector input")?;
    let mut output = vec![0.0_f32; matrix.rows];
    for (row, destination) in output.iter_mut().enumerate() {
        let mut sum = 0.0_f32;
        for (column, input_value) in input.iter().enumerate() {
            sum += matrix.values[row * matrix.columns + column] * input_value;
        }
        *destination = sum;
    }
    require_finite(&output, "matrix-vector output")?;
    Ok(output)
}

fn layer_norm(
    input: &[f32],
    weight: &[f32],
    bias: &[f32],
    epsilon: f32,
) -> Result<Vec<f32>, String> {
    require_same_lengths(input, weight, "layer norm input/weight")?;
    require_same_lengths(input, bias, "layer norm input/bias")?;
    if input.is_empty() || epsilon <= 0.0 {
        return Err("layer norm requires non-empty input and positive epsilon".to_owned());
    }
    require_finite(input, "layer norm input")?;
    let count = input.len() as f64;
    let mean = input.iter().map(|value| f64::from(*value)).sum::<f64>() / count;
    let variance = input
        .iter()
        .map(|value| {
            let centered = f64::from(*value) - mean;
            centered * centered
        })
        .sum::<f64>()
        / count;
    let inverse = (variance + f64::from(epsilon)).sqrt().recip();
    let output = input
        .iter()
        .zip(weight.iter())
        .zip(bias.iter())
        .map(|((&value, &scale), &offset)| {
            ((f64::from(value) - mean) * inverse) as f32 * scale + offset
        })
        .collect::<Vec<_>>();
    require_finite(&output, "layer norm output")?;
    Ok(output)
}

fn group_norm(
    input: &[f32],
    weight: &[f32],
    bias: &[f32],
    dimensions: Dimensions,
) -> Result<Vec<f32>, String> {
    require_length(input, dimensions.hidden_size, "group norm input")?;
    require_length(weight, dimensions.hidden_size, "group norm weight")?;
    require_length(bias, dimensions.hidden_size, "group norm bias")?;
    let epsilon = dimensions.head_size as f32 * LAYER_NORM_EPSILON;
    let mut output = vec![0.0_f32; dimensions.hidden_size];
    for head in 0..dimensions.head_count {
        let start = head * dimensions.head_size;
        let end = start + dimensions.head_size;
        let normalized = layer_norm(
            &input[start..end],
            &weight[start..end],
            &bias[start..end],
            epsilon,
        )?;
        output[start..end].copy_from_slice(&normalized);
    }
    require_finite(&output, "group norm output")?;
    Ok(output)
}

fn gate_correction(
    output: &[f32],
    r: &[f32],
    k: &[f32],
    r_k: &[f32],
    v: &[f32],
    gate: &[f32],
    dimensions: Dimensions,
) -> Result<Vec<f32>, String> {
    for (values, name) in [
        (output, "gate output"),
        (r, "gate r"),
        (k, "gate k"),
        (r_k, "gate r_k"),
        (v, "gate v"),
        (gate, "gate vector"),
    ] {
        require_length(values, dimensions.hidden_size, name)?;
    }
    let mut corrected = vec![0.0_f32; dimensions.hidden_size];
    for head in 0..dimensions.head_count {
        let base = head * dimensions.head_size;
        let mut scalar = 0.0_f32;
        for channel in 0..dimensions.head_size {
            let index = base + channel;
            scalar += r[index] * k[index] * r_k[index];
        }
        for channel in 0..dimensions.head_size {
            let index = base + channel;
            corrected[index] = (output[index] + scalar * v[index]) * gate[index];
        }
    }
    require_finite(&corrected, "gate-corrected output")?;
    Ok(corrected)
}

fn normalize_heads(input: &[f32], dimensions: Dimensions) -> Result<Vec<f32>, String> {
    require_length(input, dimensions.hidden_size, "head normalization input")?;
    let mut output = vec![0.0_f32; dimensions.hidden_size];
    for head in 0..dimensions.head_count {
        let start = head * dimensions.head_size;
        let end = start + dimensions.head_size;
        let norm = input[start..end]
            .iter()
            .map(|value| value * value)
            .sum::<f32>()
            .sqrt()
            .max(NORMALIZATION_FLOOR);
        for channel in start..end {
            output[channel] = input[channel] / norm;
        }
    }
    require_finite(&output, "head normalization output")?;
    Ok(output)
}

fn mixed(input: &[f32], previous: &[f32], mix: &[f32]) -> Result<Vec<f32>, String> {
    require_same_lengths(input, previous, "time-mix current/previous")?;
    require_same_lengths(input, mix, "time-mix current/mix")?;
    let output = input
        .iter()
        .zip(previous.iter())
        .zip(mix.iter())
        .map(|((&current, &prior), &factor)| current + (prior - current) * factor)
        .collect::<Vec<_>>();
    require_finite(&output, "time-mix output")?;
    Ok(output)
}

fn sigmoid(value: f32) -> f32 {
    if value >= 0.0 {
        let exponential = (-value).exp();
        1.0 / (1.0 + exponential)
    } else {
        let exponential = value.exp();
        exponential / (1.0 + exponential)
    }
}

fn add_vectors(left: &[f32], right: &[f32]) -> Result<Vec<f32>, String> {
    require_same_lengths(left, right, "vector addition")?;
    let output = left
        .iter()
        .zip(right.iter())
        .map(|(&left_value, &right_value)| left_value + right_value)
        .collect::<Vec<_>>();
    require_finite(&output, "vector addition output")?;
    Ok(output)
}

fn multiply_vectors(left: &[f32], right: &[f32]) -> Result<Vec<f32>, String> {
    require_same_lengths(left, right, "vector multiplication")?;
    let output = left
        .iter()
        .zip(right.iter())
        .map(|(&left_value, &right_value)| left_value * right_value)
        .collect::<Vec<_>>();
    require_finite(&output, "vector multiplication output")?;
    Ok(output)
}

fn require_same_lengths(left: &[f32], right: &[f32], name: &str) -> Result<(), String> {
    if left.len() != right.len() {
        return Err(format!(
            "{name} requires equal lengths, found {} and {}",
            left.len(),
            right.len()
        ));
    }
    Ok(())
}

fn require_length(values: &[f32], expected: usize, name: &str) -> Result<(), String> {
    if values.len() != expected {
        return Err(format!(
            "{name} requires {expected} values, found {}",
            values.len()
        ));
    }
    Ok(())
}

fn require_finite(values: &[f32], name: &str) -> Result<(), String> {
    if values.iter().any(|value| !value.is_finite()) {
        return Err(format!("{name} contains a non-finite value"));
    }
    Ok(())
}

fn max_abs_difference(left: &[f32], right: &[f32]) -> Result<f32, String> {
    require_same_lengths(left, right, "maximum absolute difference")?;
    let maximum = left
        .iter()
        .zip(right.iter())
        .map(|(&left_value, &right_value)| (left_value - right_value).abs())
        .fold(0.0_f32, f32::max);
    if !maximum.is_finite() {
        return Err("maximum absolute difference is non-finite".to_owned());
    }
    Ok(maximum)
}

fn numeric_receipt(values: &[f32]) -> Result<NumericReceipt, String> {
    if values.is_empty() {
        return Err("numeric receipt requires at least one value".to_owned());
    }
    require_finite(values, "numeric receipt")?;
    let minimum = values.iter().copied().fold(f32::INFINITY, f32::min);
    let maximum = values.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    let count = values.len() as f64;
    let mean = values.iter().map(|value| f64::from(*value)).sum::<f64>() / count;
    let l2_norm = values
        .iter()
        .map(|value| {
            let promoted = f64::from(*value);
            promoted * promoted
        })
        .sum::<f64>()
        .sqrt();
    Ok(NumericReceipt {
        element_count: values.len(),
        minimum,
        maximum,
        mean,
        l2_norm,
        finite: true,
        blake3: fingerprint_f32(values),
    })
}

fn fingerprint_token_ids(token_ids: &[usize]) -> Result<String, String> {
    let mut hasher = blake3::Hasher::new();
    for token_id in token_ids {
        let token_id = u64::try_from(*token_id)
            .map_err(|error| format!("token ID does not fit u64: {error}"))?;
        hasher.update(&token_id.to_le_bytes());
    }
    Ok(hasher.finalize().to_hex().to_string())
}

fn fingerprint_f32(values: &[f32]) -> String {
    let mut hasher = blake3::Hasher::new();
    for value in values {
        hasher.update(&value.to_bits().to_le_bytes());
    }
    hasher.finalize().to_hex().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    const SMALL_HIDDEN_SIZE: usize = 2;
    const SMALL_HEAD_SIZE: usize = 2;
    const SMALL_INTERMEDIATE_SIZE: usize = 4;
    const EXPECTED_STATE_00: f32 = 0.45;
    const EXPECTED_STATE_01: f32 = 0.65;
    const EXPECTED_STATE_10: f32 = 1.07;
    const EXPECTED_STATE_11: f32 = 1.49;
    const EXPECTED_OUTPUT_0: f32 = -0.20;
    const EXPECTED_OUTPUT_1: f32 = -0.42;
    const ASSERTION_TOLERANCE: f32 = 1.0e-6;
    const DIVERGENCE_FLOOR: f32 = 1.0e-2;
    const LOW_INTERPOLATION_GATE: f32 = 0.25;
    const HIGH_INTERPOLATION_GATE: f32 = 0.75;
    const EXPECTED_INTERPOLATED_VALUE: f32 = 0.5;
    const INVALID_INTERPOLATION_GATE: f32 = 1.5;

    fn small_dimensions() -> Dimensions {
        Dimensions {
            hidden_size: SMALL_HIDDEN_SIZE,
            head_size: SMALL_HEAD_SIZE,
            head_count: 1,
            intermediate_size: SMALL_INTERMEDIATE_SIZE,
        }
    }

    fn small_inputs() -> WkvInputs {
        WkvInputs {
            r: vec![1.0, -1.0],
            w: vec![0.5, 0.25],
            k: vec![0.2, -0.1],
            v: vec![0.5, -0.5],
            a: vec![0.1, 0.2],
            b: vec![-0.3, 0.4],
        }
    }

    #[test]
    fn matrix_recurrence_matches_manual_values_and_scalar_oracle() {
        let state = vec![1.0, 2.0, 3.0, 4.0];
        let inputs = small_inputs();
        let dimensions = small_dimensions();
        let (matrix_state, matrix_output) =
            wkv_step_matrix(&state, &inputs, dimensions).expect("matrix recurrence must succeed");
        let (oracle_state, oracle_output) =
            wkv_step_oracle(&state, &inputs, dimensions).expect("oracle recurrence must succeed");

        let expected_state = [
            EXPECTED_STATE_00,
            EXPECTED_STATE_01,
            EXPECTED_STATE_10,
            EXPECTED_STATE_11,
        ];
        let expected_output = [EXPECTED_OUTPUT_0, EXPECTED_OUTPUT_1];
        assert!(
            max_abs_difference(&matrix_state, &expected_state)
                .expect("state comparison must succeed")
                <= ASSERTION_TOLERANCE
        );
        assert!(
            max_abs_difference(&matrix_output, &expected_output)
                .expect("output comparison must succeed")
                <= ASSERTION_TOLERANCE
        );
        assert!(
            max_abs_difference(&matrix_state, &oracle_state)
                .expect("oracle state comparison must succeed")
                <= ASSERTION_TOLERANCE
        );
        assert!(
            max_abs_difference(&matrix_output, &oracle_output)
                .expect("oracle output comparison must succeed")
                <= ASSERTION_TOLERANCE
        );
    }

    #[test]
    fn recurrent_state_carry_is_discriminated_from_reset() {
        let dimensions = small_dimensions();
        let inputs = small_inputs();
        let zero = vec![0.0; SMALL_HEAD_SIZE * SMALL_HEAD_SIZE];
        let (first_state, _) =
            wkv_step_matrix(&zero, &inputs, dimensions).expect("first recurrence must succeed");
        let (carried_state, _) = wkv_step_matrix(&first_state, &inputs, dimensions)
            .expect("carried recurrence must succeed");
        let (reset_state, _) =
            wkv_step_matrix(&zero, &inputs, dimensions).expect("reset recurrence must succeed");
        assert!(
            max_abs_difference(&carried_state, &reset_state)
                .expect("state-carry comparison must succeed")
                > DIVERGENCE_FLOOR
        );
    }

    #[test]
    fn transposed_decay_axis_is_discriminated() {
        let state = vec![1.0, 2.0, 3.0, 4.0];
        let inputs = small_inputs();
        let dimensions = small_dimensions();
        let (correct, _) =
            wkv_step_matrix(&state, &inputs, dimensions).expect("correct recurrence must succeed");
        let mut wrong = correct.clone();
        for row in 0..dimensions.head_size {
            for column in 0..dimensions.head_size {
                let index = row * dimensions.head_size + column;
                let correct_decay = state[index] * inputs.w[column];
                let wrong_decay = state[index] * inputs.w[row];
                wrong[index] += wrong_decay - correct_decay;
            }
        }
        assert!(
            max_abs_difference(&correct, &wrong)
                .expect("wrong orientation comparison must succeed")
                > DIVERGENCE_FLOOR
        );
    }

    #[test]
    fn layer_and_group_normalization_are_finite_and_shaped() {
        let input = [1.0, 3.0];
        let weight = [1.0, 1.0];
        let bias = [0.0, 0.0];
        let normalized = layer_norm(&input, &weight, &bias, LAYER_NORM_EPSILON)
            .expect("layer norm must succeed");
        assert_eq!(normalized.len(), SMALL_HIDDEN_SIZE);
        assert!(normalized[0] < 0.0);
        assert!(normalized[1] > 0.0);
        let grouped = group_norm(&input, &weight, &bias, small_dimensions())
            .expect("group norm must succeed");
        assert_eq!(grouped.len(), SMALL_HIDDEN_SIZE);
        assert!(grouped.iter().all(|value| value.is_finite()));
    }

    #[test]
    fn matrix_vector_product_rejects_wrong_orientation() {
        let matrix = Matrix::new(SMALL_HIDDEN_SIZE, SMALL_HEAD_SIZE, vec![1.0, 2.0, 3.0, 4.0])
            .expect("matrix must be valid");
        let output = matvec(&matrix, &[1.0, 1.0]).expect("matrix-vector product must succeed");
        assert_eq!(output, vec![3.0, 7.0]);
        assert!(
            matvec(&matrix, &[1.0])
                .expect_err("short input must fail")
                .contains("requires")
        );
    }

    #[test]
    fn digest_verification_has_positive_and_negative_cases() {
        let checkpoint = b"real-weight-fixture";
        let expected = blake3::hash(checkpoint).to_hex().to_string();
        verify_checkpoint_digest(checkpoint, &expected).expect("matching digest must pass");
        let wrong = "0".repeat(EXPECTED_DIGEST_HEX_LENGTH);
        assert!(
            verify_checkpoint_digest(checkpoint, &wrong)
                .expect_err("wrong digest must fail")
                .contains("mismatch")
        );
        assert!(
            verify_checkpoint_digest(checkpoint, "not-a-digest")
                .expect_err("malformed digest must fail")
                .contains("lowercase hexadecimal")
        );
    }

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
    #[test]
    fn ttwkv7_bf16_artifact_is_little_endian_and_fails_closed() {
        const EXPECTED_FIXTURE_HEX: &str = "803f00c0";
        let artifact = encode_bf16_artifact("fixture", &[1, SMALL_HEAD_SIZE], &[1.0, -2.0])
            .expect("finite shaped BF16 artifact must encode");
        assert_eq!(artifact.receipt.bytes_hex, EXPECTED_FIXTURE_HEX);
        assert_eq!(
            validate_bf16_artifact(&artifact.receipt).expect("exact BF16 artifact must validate"),
            vec![1.0, -2.0]
        );

        let mut changed = artifact.receipt.clone();
        changed
            .bytes_hex
            .replace_range(..HEX_CHARACTERS_PER_BYTE, "00");
        assert!(
            validate_bf16_artifact(&changed)
                .expect_err("changed bytes under the old digest must fail")
                .contains("BLAKE3 mismatch")
        );
        let mut wrong_shape = artifact.receipt.clone();
        wrong_shape.logical_shape = vec![SMALL_HEAD_SIZE, SMALL_HEAD_SIZE];
        assert!(
            validate_bf16_artifact(&wrong_shape)
                .expect_err("wrong shape must fail")
                .contains("shape requires")
        );
        let mut odd_hex = artifact.receipt.clone();
        odd_hex.bytes_hex.pop();
        assert!(
            validate_bf16_artifact(&odd_hex)
                .expect_err("odd hexadecimal length must fail")
                .contains("even length")
        );
        let mut uppercase_hex = artifact.receipt;
        uppercase_hex.bytes_hex = "803F00C0".to_owned();
        assert!(
            validate_bf16_artifact(&uppercase_hex)
                .expect_err("uppercase hexadecimal must fail")
                .contains("non-lowercase-hexadecimal")
        );
        assert!(
            encode_bf16_artifact("non_finite", &[1], &[f32::NAN])
                .expect_err("non-finite source must fail")
                .contains("non-finite")
        );
        assert!(
            encode_bf16_artifact("bad_shape", &[], &[])
                .expect_err("empty shape must fail")
                .contains("must be positive")
        );
    }

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
    #[test]
    fn ttwkv7_combined_identity_binds_order_and_every_byte() {
        let artifacts = TTWKV7_BOUNDARY_ARTIFACT_ORDER
            .iter()
            .enumerate()
            .map(|(index, name)| {
                let shape = expected_ttwkv7_artifact_shape(name)
                    .expect("reviewed artifact must have a shape");
                let element_count =
                    checked_shape_elements(shape, name).expect("reviewed artifact shape must fit");
                let values = vec![index as f32 + 1.0; element_count];
                encode_bf16_artifact(name, shape, &values)
                    .expect("ordered fixture artifact must encode")
                    .receipt
            })
            .collect::<Vec<_>>();
        let first =
            ordered_artifact_blake3(&artifacts).expect("complete ordered fixture must hash");
        let second = ordered_artifact_blake3(&artifacts)
            .expect("repeated complete ordered fixture must hash");
        assert_eq!(first, second);
        assert_eq!(first.len(), EXPECTED_DIGEST_HEX_LENGTH);

        let mut reordered = artifacts.clone();
        reordered.swap(0, 1);
        assert!(
            ordered_artifact_blake3(&reordered)
                .expect_err("reordered ABI artifacts must fail")
                .contains("artifact order")
        );
        let mut wrong_shape = artifacts.clone();
        wrong_shape[0].logical_shape = vec![1, wrong_shape[0].element_count];
        assert!(
            ordered_artifact_blake3(&wrong_shape)
                .expect_err("changed logical shape must fail")
                .contains("logical shape must be")
        );
        let mut changed = artifacts;
        changed[0]
            .bytes_hex
            .replace_range(..HEX_CHARACTERS_PER_BYTE, "00");
        assert!(
            ordered_artifact_blake3(&changed)
                .expect_err("changed artifact bytes must fail")
                .contains("BLAKE3 mismatch")
        );
    }

    #[test]
    fn tensor_dtype_and_shape_errors_fail_closed() {
        let f32_bytes = 1.0_f32.to_le_bytes();
        let tensor = TensorView::new(Dtype::F32, vec![1], &f32_bytes)
            .expect("F32 fixture tensor must be valid");
        assert!(
            require_dtype(&tensor, "fixture", Dtype::BF16)
                .expect_err("wrong dtype must fail")
                .contains("must have dtype")
        );
        assert!(
            require_shape(&tensor, "fixture", &[SMALL_HIDDEN_SIZE])
                .expect_err("wrong tensor shape must fail")
                .contains("must have shape")
        );
    }

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.greedy_token]
    #[test]
    fn token_local_value_interpolation_is_bounded_and_oriented() {
        let projected = [0.0, 2.0];
        let anchor = [2.0, 0.0];
        let gates = [LOW_INTERPOLATION_GATE, HIGH_INTERPOLATION_GATE];
        let interpolated = interpolate_values(&projected, &anchor, &gates)
            .expect("bounded value interpolation must succeed");
        assert_eq!(
            interpolated,
            vec![EXPECTED_INTERPOLATED_VALUE, EXPECTED_INTERPOLATED_VALUE]
        );
        assert!(
            interpolate_values(&projected, &anchor, &[INVALID_INTERPOLATION_GATE, 0.0])
                .expect_err("out-of-range gate must fail")
                .contains("inclusive range")
        );
        assert!(
            interpolate_values(&projected, &[2.0], &gates)
                .expect_err("wrong anchor shape must fail")
                .contains("equal lengths")
        );
    }

    #[test]
    fn top_two_ranking_is_deterministic_and_rejects_non_finite_logits() {
        let ranked = rank_top_two([
            RankedLogit {
                token_id: 3,
                logit: 2.0,
            },
            RankedLogit {
                token_id: 1,
                logit: 2.0,
            },
            RankedLogit {
                token_id: 2,
                logit: 1.0,
            },
        ])
        .expect("finite ranking must succeed");
        assert_eq!(ranked.first.token_id, 1);
        assert_eq!(ranked.second.token_id, 3);
        assert!(
            rank_top_two([RankedLogit {
                token_id: 0,
                logit: f32::NAN,
            }])
            .expect_err("non-finite ranking must fail")
            .contains("non-finite")
        );
        assert!(
            rank_top_two([RankedLogit {
                token_id: 0,
                logit: 1.0,
            }])
            .expect_err("a single logit must fail")
            .contains("at least two")
        );
    }

    #[test]
    fn direct_bf16_head_audit_accepts_rows_and_rejects_transpose() {
        let hidden_size = SMALL_HIDDEN_SIZE;
        let mut values = vec![0.0_f32; VOCABULARY_SIZE * hidden_size];
        values[0] = 1.0;
        values[hidden_size + 1] = 2.0;
        let bytes = values
            .iter()
            .flat_map(|value| bf16::from_f32(*value).to_bits().to_le_bytes())
            .collect::<Vec<_>>();
        let tensor = TensorView::new(Dtype::BF16, vec![VOCABULARY_SIZE, hidden_size], &bytes)
            .expect("BF16 head fixture must be valid");
        let direct = direct_bf16_head_top_two(&tensor, &[1.0, 1.0], hidden_size)
            .expect("direct head audit must succeed");
        assert_eq!(direct.first.token_id, 1);
        assert_eq!(direct.first.logit, 2.0);
        assert_eq!(direct.second.token_id, 0);
        assert_eq!(direct.second.logit, 1.0);

        let transposed = TensorView::new(Dtype::BF16, vec![hidden_size, VOCABULARY_SIZE], &bytes)
            .expect("transposed BF16 fixture must be structurally valid");
        assert!(
            direct_bf16_head_top_two(&transposed, &[1.0, 1.0], hidden_size)
                .expect_err("transposed head must fail")
                .contains("must have shape")
        );
    }

    #[test]
    fn full_model_rejects_incomplete_layer_inventory() {
        assert!(
            run_model_sequence(&[], [&[], &[]])
                .expect_err("empty layer inventory must fail")
                .contains(&format!("requires {MODEL_LAYER_COUNT} layers"))
        );
    }

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
    #[test]
    fn model_execution_state_rejects_missing_or_malformed_layer_state() {
        let dimensions = Dimensions::reviewed();
        let state =
            ModelExecutionState::zero(dimensions).expect("complete zero model state must be valid");
        state
            .validate(dimensions)
            .expect("complete zero model state must validate");

        let mut missing_layer = state.clone();
        missing_layer.layers.pop();
        assert!(
            missing_layer
                .validate(dimensions)
                .expect_err("missing layer state must fail")
                .contains("layer and oracle slots")
        );

        let mut malformed_attention = state;
        malformed_attention.layers[LAYER_INDEX]
            .attention_previous
            .pop();
        assert!(
            malformed_attention
                .validate(dimensions)
                .expect_err("malformed attention state must fail")
                .contains("attention state")
        );
    }

    #[test]
    fn decode_chain_requires_selected_tokens_as_next_inputs() {
        let valid_processed = [
            MODEL_CONFIG_BOS_TOKEN_ID,
            MODEL_CONFIG_EOS_TOKEN_ID,
            MODEL_CONFIG_BOS_TOKEN_ID,
        ];
        let valid_generated = [
            MODEL_CONFIG_EOS_TOKEN_ID,
            MODEL_CONFIG_BOS_TOKEN_ID,
            MODEL_CONFIG_EOS_TOKEN_ID,
        ];
        validate_decode_chain(&valid_processed, &valid_generated)
            .expect("generated tokens used as next inputs must pass");

        let stale_processed = [
            MODEL_CONFIG_BOS_TOKEN_ID,
            MODEL_CONFIG_BOS_TOKEN_ID,
            MODEL_CONFIG_BOS_TOKEN_ID,
        ];
        assert!(
            validate_decode_chain(&stale_processed, &valid_generated)
                .expect_err("stale next input must fail")
                .contains("prior generated token")
        );
        assert!(
            validate_decode_chain(&[MODEL_CONFIG_BOS_TOKEN_ID], &[MODEL_CONFIG_EOS_TOKEN_ID],)
                .expect_err("short decode chain must fail")
                .contains("requires")
        );
    }

    #[test]
    fn replay_tolerance_accepts_exact_match_and_rejects_excess() {
        require_replay_tolerance(0.0, "fixture", LAYER_INDEX)
            .expect("exact replay match must pass");
        assert!(
            require_replay_tolerance(REPLAY_TOLERANCE + REPLAY_TOLERANCE, "fixture", LAYER_INDEX,)
                .expect_err("excess replay deviation must fail")
                .contains("exceeds")
        );
        assert!(
            require_replay_tolerance(f32::NAN, "fixture", LAYER_INDEX)
                .expect_err("non-finite replay deviation must fail")
                .contains("exceeds")
        );
    }

    #[test]
    fn state_carry_discriminator_rejects_reset_equivalence() {
        require_state_carry_divergence(
            STATE_CARRY_DIVERGENCE_FLOOR + STATE_CARRY_DIVERGENCE_FLOOR,
            LAYER_INDEX + 1,
        )
        .expect("visible retained-state divergence must pass");
        assert!(
            require_state_carry_divergence(0.0, LAYER_INDEX + 1)
                .expect_err("reset-equivalent state must fail")
                .contains("must exceed")
        );
    }

    #[test]
    fn non_finite_and_shape_errors_fail_closed() {
        assert!(
            require_finite(&[f32::NAN], "fixture")
                .expect_err("NaN must fail")
                .contains("non-finite")
        );
        assert!(
            Matrix::new(SMALL_HIDDEN_SIZE, SMALL_HEAD_SIZE, vec![1.0])
                .expect_err("wrong matrix shape must fail")
                .contains("requires")
        );
        let invalid = Dimensions {
            hidden_size: SMALL_INTERMEDIATE_SIZE,
            head_size: SMALL_HEAD_SIZE + 1,
            head_count: 1,
            intermediate_size: SMALL_INTERMEDIATE_SIZE,
        };
        assert!(
            invalid
                .validate()
                .expect_err("indivisible dimensions must fail")
                .contains("divisible")
        );
    }

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
    #[test]
    fn tokenizer_literals_accept_reviewed_bytes_and_unicode() {
        assert_eq!(
            parse_python_bytes_literal(r"b'\xff'").expect("escaped byte literal must parse"),
            vec![u8::MAX]
        );
        assert_eq!(
            parse_python_bytes_literal("'é'").expect("Unicode literal must parse"),
            "é".as_bytes()
        );
        assert_eq!(
            parse_python_bytes_literal(r"'\n\u03bb'").expect("escaped Unicode literal must parse"),
            "\nλ".as_bytes()
        );
        assert_eq!(
            parse_vocabulary_line(r"261 '\n\n' 2").expect("reviewed EOS row must parse"),
            (BYTE_VOCABULARY_EOS_TOKEN_ID, b"\n\n".to_vec())
        );
    }

    #[test]
    fn tokenizer_literals_and_rows_fail_closed() {
        assert!(
            parse_python_bytes_literal(r"b'\u0041'")
                .expect_err("Unicode escape in bytes literal must fail")
                .contains("Unicode escape")
        );
        assert!(
            parse_python_bytes_literal(r"'\N{LATIN CAPITAL LETTER A}'")
                .expect_err("named Unicode escape must fail")
                .contains("unsupported escape")
        );
        assert!(
            parse_vocabulary_line(r"261 '\n\n' 1")
                .expect_err("wrong declared byte length must fail")
                .contains("declares")
        );
        assert!(
            parse_vocabulary_line("missing-fields")
                .expect_err("malformed row must fail")
                .contains("separator")
        );
    }

    #[test]
    fn tokenizer_uses_greedy_longest_prefix_and_exact_bytes() {
        let tokenizer = RwkvTokenizer::from_tokens(vec![
            None,
            Some(b"a".to_vec()),
            Some(b"ab".to_vec()),
            Some(b"b".to_vec()),
        ])
        .expect("compact tokenizer fixture must be valid");
        let encoded = tokenizer
            .encode_bytes(b"abab")
            .expect("overlapping token fixture must encode");
        assert_eq!(encoded, vec![2, 2]);
        assert_eq!(
            tokenizer
                .decode_bytes(&encoded)
                .expect("encoded fixture must decode"),
            b"abab"
        );
        assert!(
            tokenizer
                .decode_bytes(&[TOKENIZER_BOS_TOKEN_ID])
                .expect_err("special ID must not decode as ordinary bytes")
                .contains("special")
        );
        assert!(
            tokenizer
                .decode_bytes(&[4])
                .expect_err("missing vocabulary ID must fail")
                .contains("cannot decode")
        );
        assert!(
            tokenizer
                .encode_bytes(b"c")
                .expect_err("unknown source byte must fail")
                .contains("source offset")
        );
        let wrapper_text = format!("{TOKENIZER_SPECIAL_TEXT}a{TOKENIZER_EOS_TEXT}");
        let wrapper_ids = tokenizer
            .encode_wrapper_text(&wrapper_text)
            .expect("added special tokens must encode outside the byte trie");
        assert_eq!(
            wrapper_ids,
            vec![TOKENIZER_BOS_TOKEN_ID, 1, TOKENIZER_WRAPPER_EOS_TOKEN_ID,]
        );
        assert_eq!(
            tokenizer
                .decode_wrapper_bytes(&wrapper_ids)
                .expect("added special tokens must decode"),
            wrapper_text.as_bytes()
        );
    }

    #[test]
    fn tokenizer_rejects_missing_and_duplicate_token_entries() {
        assert!(
            RwkvTokenizer::from_tokens(vec![None, Some(b"a".to_vec()), None])
                .expect_err("missing token entry must fail")
                .contains("missing ID")
        );
        assert!(
            RwkvTokenizer::from_tokens(vec![None, Some(b"a".to_vec()), Some(b"a".to_vec()),])
                .expect_err("duplicate token bytes must fail")
                .contains("duplicate")
        );
    }

    // r[verify onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
    #[test]
    fn bounded_prompt_arguments_render_exact_chat_text() {
        let arguments = vec![
            PROMPT_NEW_TOKEN_LIMIT_OPTION.to_owned(),
            PROMPT_MAX_NEW_TOKEN_COUNT.to_string(),
            PROMPT_MESSAGE_OPTION.to_owned(),
            "Hello λ".to_owned(),
            PROMPT_TOKEN_LIMIT_OPTION.to_owned(),
            PROMPT_MAX_TOKEN_COUNT.to_string(),
        ];
        let request = parse_prompt_arguments(&arguments)
            .expect("complete bounded prompt arguments must parse");
        assert_eq!(request.user_message, "Hello λ");
        assert_eq!(request.max_prompt_tokens, PROMPT_MAX_TOKEN_COUNT);
        assert_eq!(request.max_new_tokens, PROMPT_MAX_NEW_TOKEN_COUNT);
        assert_eq!(
            request
                .render_chat_prompt()
                .expect("bounded message must render"),
            format!("{TOKENIZER_SPECIAL_TEXT}User: Hello λ{TOKENIZER_EOS_TEXT}Assistant:")
        );
        require_prompt_token_limit(PROMPT_MAX_TOKEN_COUNT, PROMPT_MAX_TOKEN_COUNT)
            .expect("exact prompt token cap must pass");
    }

    #[test]
    fn bounded_prompt_arguments_fail_closed() {
        let duplicate = vec![
            PROMPT_MESSAGE_OPTION.to_owned(),
            "first".to_owned(),
            PROMPT_MESSAGE_OPTION.to_owned(),
            "second".to_owned(),
            PROMPT_NEW_TOKEN_LIMIT_OPTION.to_owned(),
            "1".to_owned(),
        ];
        assert!(
            parse_prompt_arguments(&duplicate)
                .expect_err("duplicate prompt option must fail")
                .contains("duplicate")
        );

        let unknown = vec![
            "--unknown".to_owned(),
            "value".to_owned(),
            PROMPT_MESSAGE_OPTION.to_owned(),
            "hello".to_owned(),
            PROMPT_NEW_TOKEN_LIMIT_OPTION.to_owned(),
            "1".to_owned(),
        ];
        assert!(
            parse_prompt_arguments(&unknown)
                .expect_err("unknown option must fail")
                .contains("unknown option")
        );

        let invalid_number = vec![
            PROMPT_MESSAGE_OPTION.to_owned(),
            "hello".to_owned(),
            PROMPT_TOKEN_LIMIT_OPTION.to_owned(),
            "not-a-number".to_owned(),
            PROMPT_NEW_TOKEN_LIMIT_OPTION.to_owned(),
            "1".to_owned(),
        ];
        assert!(
            parse_prompt_arguments(&invalid_number)
                .expect_err("non-integer limit must fail")
                .contains("positive integer")
        );

        for request in [
            PromptRequest {
                user_message: "hello".to_owned(),
                max_prompt_tokens: 0,
                max_new_tokens: 1,
            },
            PromptRequest {
                user_message: "hello".to_owned(),
                max_prompt_tokens: PROMPT_MAX_TOKEN_COUNT + 1,
                max_new_tokens: 1,
            },
            PromptRequest {
                user_message: "hello".to_owned(),
                max_prompt_tokens: 1,
                max_new_tokens: PROMPT_MAX_NEW_TOKEN_COUNT + 1,
            },
            PromptRequest {
                user_message: "a".repeat(PROMPT_MAX_MESSAGE_BYTES + 1),
                max_prompt_tokens: 1,
                max_new_tokens: 1,
            },
        ] {
            request
                .validate()
                .expect_err("zero or excessive request bound must fail");
        }
        require_prompt_token_limit(PROMPT_MAX_TOKEN_COUNT + 1, PROMPT_MAX_TOKEN_COUNT)
            .expect_err("actual prompt token excess must fail");
    }

    #[test]
    fn bounded_prompt_utf8_classification_preserves_exact_bytes() {
        const INCOMPLETE_UTF8_LEAD_BYTE: u8 = 0xf0;
        assert_eq!(decode_complete_utf8("λ".as_bytes()), Some("λ".to_owned()));
        assert_eq!(decode_complete_utf8(&[INCOMPLETE_UTF8_LEAD_BYTE]), None);
        assert_eq!(encode_hex(&[INCOMPLETE_UTF8_LEAD_BYTE]), "f0");
    }

    #[test]
    fn token_authority_conflict_remains_explicit() {
        assert_eq!(MODEL_CONFIG_BOS_TOKEN_ID, 1);
        assert_eq!(MODEL_CONFIG_EOS_TOKEN_ID, 2);
        assert_eq!(TOKENIZER_BOS_TOKEN_ID, 0);
        assert_eq!(BYTE_VOCABULARY_EOS_TOKEN_ID, 261);
        assert_eq!(TOKENIZER_WRAPPER_EOS_TOKEN_ID, 65_530);
        assert_eq!(GENERATION_CONFIG_BOS_TOKEN_ID, 0);
        assert_eq!(GENERATION_CONFIG_EOS_TOKEN_ID, 0);
        assert_ne!(MODEL_CONFIG_BOS_TOKEN_ID, TOKENIZER_BOS_TOKEN_ID);
        assert_ne!(MODEL_CONFIG_EOS_TOKEN_ID, BYTE_VOCABULARY_EOS_TOKEN_ID);
        assert_ne!(MODEL_CONFIG_EOS_TOKEN_ID, TOKENIZER_WRAPPER_EOS_TOKEN_ID);
        assert_ne!(MODEL_CONFIG_EOS_TOKEN_ID, GENERATION_CONFIG_EOS_TOKEN_ID);
    }

    #[test]
    fn fingerprints_are_stable_and_order_sensitive() {
        let first = fingerprint_f32(&[1.0, 2.0, 3.0]);
        let second = fingerprint_f32(&[1.0, 2.0, 3.0]);
        let reordered = fingerprint_f32(&[3.0, 2.0, 1.0]);
        assert_eq!(first, second);
        assert_ne!(first, reordered);
        assert_eq!(first.len(), EXPECTED_DIGEST_HEX_LENGTH);
        let token_ids =
            fingerprint_token_ids(&[1, 2, 3]).expect("token ID fingerprint must succeed");
        let repeated =
            fingerprint_token_ids(&[1, 2, 3]).expect("repeated token ID fingerprint must succeed");
        let reordered_ids =
            fingerprint_token_ids(&[3, 2, 1]).expect("reordered token ID fingerprint must succeed");
        assert_eq!(token_ids, repeated);
        assert_ne!(token_ids, reordered_ids);
    }
}
