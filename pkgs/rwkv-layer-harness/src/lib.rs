use half::bf16;
use safetensors::{Dtype, SafeTensors, tensor::TensorView};
use serde::Serialize;

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
pub const BOS_TOKEN_ID: usize = 1;
pub const EOS_TOKEN_ID: usize = 2;
pub const RECEIPT_SCHEMA_VERSION: u32 = 1;
pub const DECODE_STEP_COUNT: usize = 3;
pub const MODEL_REVISION: &str = "d81965cb4e1a9f96696b4f70b84212b8f2e43216";
pub const MODEL_SHA256_SRI: &str = "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=";
pub const MODEL_BLAKE3: &str = "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5";
pub const MODEL_BYTE_COUNT: u64 = 382_111_072;
pub const ORACLE_TOLERANCE: f32 = 1.0e-5;
pub const REPLAY_TOLERANCE: f32 = 1.0e-5;
pub const STATE_CARRY_DIVERGENCE_FLOOR: f32 = 1.0e-4;
const LAYER_NORM_EPSILON: f32 = 1.0e-5;
const NORMALIZATION_FLOOR: f32 = 1.0e-12;
const NEGATIVE_INVERSE_SQRT_E: f32 = -0.606_530_67;
const BF16_BYTE_WIDTH: usize = 2;
const HEX_RADIX: u32 = 16;
const EXPECTED_DIGEST_HEX_LENGTH: usize = 64;
const LAYER_INDEX: usize = 0;
const TOKEN_COUNT: usize = 2;
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
    "Continuing after EOS is diagnostic and is not normal stop behavior.",
    "The final selected token is not executed as a recurrent next step.",
    "No sampling or unbounded generation is established.",
    "No arbitrary prompt or long-context stability is established.",
    "No FLA or official-runtime bit parity is established.",
    "No general RWKV correctness is established.",
    "No P150 numerical parity is established.",
    "No ttWKV7 integration or repaired-reader completion is established.",
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

    fn flattened_matrices(&self) -> Vec<f32> {
        self.layers
            .iter()
            .flat_map(|state| state.matrix.iter().copied())
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
struct TimeMixOutput {
    projected_value: Vec<f32>,
    wkv_inputs: WkvInputs,
    wkv_output: Vec<f32>,
    oracle_output: Vec<f32>,
    matrix_state: Vec<f32>,
    oracle_state: Vec<f32>,
}

#[derive(Clone, Debug)]
struct SequenceResult {
    final_output: Vec<f32>,
    final_state: Vec<f32>,
    second_inputs: WkvInputs,
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
pub struct DecodeStepReceipt {
    pub step_index: usize,
    pub input_token_id: usize,
    pub generated_token_id: usize,
    pub generated_logit: f32,
    pub runner_up_token_id: usize,
    pub runner_up_logit: f32,
    pub greedy_margin: f32,
    pub eos_selected: bool,
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
    pub eos_token_id: usize,
    pub eos_observed_steps: Vec<usize>,
    pub continued_after_eos: bool,
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
    let bos = embedding_row(&embedding, BOS_TOKEN_ID, dimensions.hidden_size)?;
    let eos = embedding_row(&embedding, EOS_TOKEN_ID, dimensions.hidden_size)?;
    let result = run_sequence(&weights, [&bos, &eos])?;

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
        token_ids: [BOS_TOKEN_ID, EOS_TOKEN_ID],
        arithmetic_precision: ARITHMETIC_PRECISION,
        second_token_wkv: WkvReceipt {
            r: numeric_receipt(&result.second_inputs.r)?,
            w: numeric_receipt(&result.second_inputs.w)?,
            k: numeric_receipt(&result.second_inputs.k)?,
            v: numeric_receipt(&result.second_inputs.v)?,
            a: numeric_receipt(&result.second_inputs.a)?,
            b: numeric_receipt(&result.second_inputs.b)?,
        },
        final_state: numeric_receipt(&result.final_state)?,
        final_layer_output: numeric_receipt(&result.final_output)?,
        maximum_oracle_state_deviation: result.maximum_state_deviation,
        maximum_oracle_output_deviation: result.maximum_output_deviation,
        oracle_tolerance: ORACLE_TOLERANCE,
        non_claims: NON_CLAIMS.to_vec(),
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
    let bos = embedding_row(&embedding, BOS_TOKEN_ID, dimensions.hidden_size)?;
    let eos = embedding_row(&embedding, EOS_TOKEN_ID, dimensions.hidden_size)?;
    let sequence = run_model_sequence(&weights, [&bos, &eos])?;

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
        prefix_token_ids: [BOS_TOKEN_ID, EOS_TOKEN_ID],
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
    let mut input_token_id = BOS_TOKEN_ID;
    let mut processed_input_ids = Vec::with_capacity(DECODE_STEP_COUNT);
    let mut generated_token_ids = Vec::with_capacity(DECODE_STEP_COUNT);
    let mut eos_observed_steps = Vec::new();
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
        let eos_selected = generated.token_id == EOS_TOKEN_ID;
        if eos_selected {
            eos_observed_steps.push(step_index);
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
            eos_selected,
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
    let continued_after_eos = eos_observed_steps
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
        seed_token_id: BOS_TOKEN_ID,
        generated_step_count: DECODE_STEP_COUNT,
        processed_input_ids,
        generated_token_ids,
        eos_token_id: EOS_TOKEN_ID,
        eos_observed_steps,
        continued_after_eos,
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
    if processed_input_ids.first().copied() != Some(BOS_TOKEN_ID) {
        return Err(format!(
            "decode chain must start with BOS token {BOS_TOKEN_ID}"
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
    require_length(input, hidden_size, "direct head input")?;
    require_finite(input, "direct head input")?;
    let row_bytes = hidden_size
        .checked_mul(BF16_BYTE_WIDTH)
        .ok_or_else(|| "LM-head row byte count overflows usize".to_owned())?;
    let ranked = (0..VOCABULARY_SIZE).map(|token_id| {
        let start = token_id
            .checked_mul(row_bytes)
            .ok_or_else(|| "LM-head row offset overflows usize".to_owned())?;
        let end = start
            .checked_add(row_bytes)
            .ok_or_else(|| "LM-head row end overflows usize".to_owned())?;
        let bytes = tensor
            .data()
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

fn run_sequence(
    weights: &LayerWeights,
    embeddings: [&[f32]; TOKEN_COUNT],
) -> Result<SequenceResult, String> {
    let dimensions = weights.dimensions;
    let mut state = LayerState::zero(dimensions)?;
    let mut oracle_state = state.matrix.clone();
    let mut maximum_state_deviation = 0.0_f32;
    let mut maximum_output_deviation = 0.0_f32;
    let mut second_inputs = None;
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
        let after_attention = add_vectors(&residual, &time.wkv_output)?;
        let ffn_input = layer_norm(
            &after_attention,
            &weights.ffn_norm_weight,
            &weights.ffn_norm_bias,
            LAYER_NORM_EPSILON,
        )?;
        let ffn_output = channel_mix(weights, &ffn_input, &state.ffn_previous)?;
        state.ffn_previous.clone_from(&ffn_input);
        final_output = add_vectors(&after_attention, &ffn_output)?;
        if token_index + 1 == TOKEN_COUNT {
            second_inputs = Some(time.wkv_inputs);
        }
    }

    let second_inputs =
        second_inputs.ok_or_else(|| "second-token inputs were not produced".to_owned())?;
    require_finite(&final_output, "final layer output")?;
    require_finite(&state.matrix, "final recurrent state")?;
    Ok(SequenceResult {
        final_output,
        final_state: state.matrix,
        second_inputs,
        maximum_state_deviation,
        maximum_output_deviation,
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
    mut execution: ModelExecutionState,
) -> Result<(ModelExecutionState, Vec<f32>), String> {
    validate_model_weights(weights)?;
    let dimensions = Dimensions::reviewed();
    execution.validate(dimensions)?;
    require_length(embedding, dimensions.hidden_size, "model embedding")?;
    let mut hidden = embedding.to_vec();
    let mut value_anchor = None;
    for (layer_index, layer) in weights.iter().enumerate() {
        let residual = apply_pre_norm(layer, &hidden)?;
        let attention_input = layer_norm(
            &residual,
            &layer.attn_norm_weight,
            &layer.attn_norm_bias,
            LAYER_NORM_EPSILON,
        )?;
        let time = time_mix(
            layer,
            &attention_input,
            &execution.layers[layer_index].attention_previous,
            &execution.layers[layer_index].matrix,
            &execution.oracle_matrices[layer_index],
            value_anchor.as_deref(),
        )?;
        if layer_index == LAYER_INDEX {
            value_anchor = Some(time.projected_value.clone());
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

        let after_attention = add_vectors(&residual, &time.wkv_output)?;
        let ffn_input = layer_norm(
            &after_attention,
            &layer.ffn_norm_weight,
            &layer.ffn_norm_bias,
            LAYER_NORM_EPSILON,
        )?;
        let ffn_output = channel_mix(
            layer,
            &ffn_input,
            &execution.layers[layer_index].ffn_previous,
        )?;
        execution.layers[layer_index]
            .ffn_previous
            .clone_from(&ffn_input);
        hidden = add_vectors(&after_attention, &ffn_output)?;
    }
    if value_anchor.is_none() {
        return Err("layer zero did not establish v_first".to_owned());
    }
    require_finite(&hidden, "full-model token output")?;
    execution.validate(dimensions)?;
    Ok((execution, hidden))
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
    let inputs = WkvInputs { r, w, k, v, a, b };

    let (next_state, raw_output) = wkv_step_matrix(state, &inputs, dimensions)?;
    let (next_oracle_state, oracle_raw_output) =
        wkv_step_oracle(oracle_state, &inputs, dimensions)?;
    let normalized = group_norm(
        &raw_output,
        &weights.group_norm_weight,
        &weights.group_norm_bias,
        dimensions,
    )?;
    let corrected = gate_correction(
        &normalized,
        &inputs.r,
        &inputs.k,
        &weights.r_k,
        &inputs.v,
        &gate,
        dimensions,
    )?;
    let attention_output = matvec(&weights.output_projection, &corrected)?;
    require_finite(&attention_output, "attention output")?;

    let oracle_normalized = group_norm(
        &oracle_raw_output,
        &weights.group_norm_weight,
        &weights.group_norm_bias,
        dimensions,
    )?;
    let oracle_corrected = gate_correction(
        &oracle_normalized,
        &inputs.r,
        &inputs.k,
        &weights.r_k,
        &inputs.v,
        &gate,
        dimensions,
    )?;
    let oracle_output = matvec(&weights.output_projection, &oracle_corrected)?;
    let state_deviation = max_abs_difference(&next_state, &next_oracle_state)?;
    if state_deviation > ORACLE_TOLERANCE {
        return Err(format!(
            "time-mix recurrence state deviation {state_deviation} exceeds {ORACLE_TOLERANCE}"
        ));
    }

    Ok(TimeMixOutput {
        projected_value,
        wkv_inputs: inputs,
        wkv_output: attention_output,
        oracle_output,
        matrix_state: next_state,
        oracle_state: next_oracle_state,
    })
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
        let valid_processed = [BOS_TOKEN_ID, EOS_TOKEN_ID, BOS_TOKEN_ID];
        let valid_generated = [EOS_TOKEN_ID, BOS_TOKEN_ID, EOS_TOKEN_ID];
        validate_decode_chain(&valid_processed, &valid_generated)
            .expect("generated tokens used as next inputs must pass");

        let stale_processed = [BOS_TOKEN_ID, BOS_TOKEN_ID, BOS_TOKEN_ID];
        assert!(
            validate_decode_chain(&stale_processed, &valid_generated)
                .expect_err("stale next input must fail")
                .contains("prior generated token")
        );
        assert!(
            validate_decode_chain(&[BOS_TOKEN_ID], &[EOS_TOKEN_ID])
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

    #[test]
    fn fingerprints_are_stable_and_order_sensitive() {
        let first = fingerprint_f32(&[1.0, 2.0, 3.0]);
        let second = fingerprint_f32(&[1.0, 2.0, 3.0]);
        let reordered = fingerprint_f32(&[3.0, 2.0, 1.0]);
        assert_eq!(first, second);
        assert_ne!(first, reordered);
        assert_eq!(first.len(), EXPECTED_DIGEST_HEX_LENGTH);
    }
}
