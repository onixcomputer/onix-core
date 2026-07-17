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
pub const VOCABULARY_SIZE: usize = 65536;
pub const BOS_TOKEN_ID: usize = 1;
pub const EOS_TOKEN_ID: usize = 2;
pub const RECEIPT_SCHEMA_VERSION: u32 = 1;
pub const MODEL_REVISION: &str = "d81965cb4e1a9f96696b4f70b84212b8f2e43216";
pub const MODEL_SHA256_SRI: &str = "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=";
pub const MODEL_BLAKE3: &str = "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5";
pub const MODEL_BYTE_COUNT: u64 = 382_111_072;
pub const ORACLE_TOLERANCE: f32 = 1.0e-5;
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
    dimensions: Dimensions,
    pre_norm_weight: Vec<f32>,
    pre_norm_bias: Vec<f32>,
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
    dimensions.validate()?;
    let hidden = dimensions.hidden_size;
    let intermediate = dimensions.intermediate_size;
    let head_count = dimensions.head_count;
    let head_size = dimensions.head_size;
    Ok(LayerWeights {
        dimensions,
        pre_norm_weight: vector(tensors, "model.layers.0.pre_norm.weight", hidden)?,
        pre_norm_bias: vector(tensors, "model.layers.0.pre_norm.bias", hidden)?,
        attn_norm_weight: vector(tensors, "model.layers.0.attn_norm.weight", hidden)?,
        attn_norm_bias: vector(tensors, "model.layers.0.attn_norm.bias", hidden)?,
        x_r: flexible_vector(tensors, "model.layers.0.attn.x_r", hidden)?,
        x_w: flexible_vector(tensors, "model.layers.0.attn.x_w", hidden)?,
        x_k: flexible_vector(tensors, "model.layers.0.attn.x_k", hidden)?,
        x_v: flexible_vector(tensors, "model.layers.0.attn.x_v", hidden)?,
        x_a: flexible_vector(tensors, "model.layers.0.attn.x_a", hidden)?,
        x_g: flexible_vector(tensors, "model.layers.0.attn.x_g", hidden)?,
        r_projection: matrix(tensors, "model.layers.0.attn.r_proj.weight", hidden, hidden)?,
        k_projection: matrix(tensors, "model.layers.0.attn.k_proj.weight", hidden, hidden)?,
        v_projection: matrix(tensors, "model.layers.0.attn.v_proj.weight", hidden, hidden)?,
        output_projection: matrix(tensors, "model.layers.0.attn.o_proj.weight", hidden, hidden)?,
        w_down: matrix(
            tensors,
            "model.layers.0.attn.w_lora.lora.0.weight",
            DECAY_RANK,
            hidden,
        )?,
        w_up: matrix(
            tensors,
            "model.layers.0.attn.w_lora.lora.2.weight",
            hidden,
            DECAY_RANK,
        )?,
        w_bias: vector(tensors, "model.layers.0.attn.w_lora.lora.2.bias", hidden)?,
        a_down: matrix(
            tensors,
            "model.layers.0.attn.a_lora.lora.0.weight",
            A_RANK,
            hidden,
        )?,
        a_up: matrix(
            tensors,
            "model.layers.0.attn.a_lora.lora.2.weight",
            hidden,
            A_RANK,
        )?,
        a_bias: vector(tensors, "model.layers.0.attn.a_lora.lora.2.bias", hidden)?,
        gate_down: matrix(
            tensors,
            "model.layers.0.attn.g_lora.lora.0.weight",
            GATE_RANK,
            hidden,
        )?,
        gate_up: matrix(
            tensors,
            "model.layers.0.attn.g_lora.lora.2.weight",
            hidden,
            GATE_RANK,
        )?,
        k_k: vector(tensors, "model.layers.0.attn.k_k", hidden)?,
        k_a: vector(tensors, "model.layers.0.attn.k_a", hidden)?,
        r_k: shaped_vector(tensors, "model.layers.0.attn.r_k", &[head_count, head_size])?,
        group_norm_weight: vector(tensors, "model.layers.0.attn.g_norm.weight", hidden)?,
        group_norm_bias: vector(tensors, "model.layers.0.attn.g_norm.bias", hidden)?,
        ffn_norm_weight: vector(tensors, "model.layers.0.ffn_norm.weight", hidden)?,
        ffn_norm_bias: vector(tensors, "model.layers.0.ffn_norm.bias", hidden)?,
        ffn_x_k: vector(tensors, "model.layers.0.ffn.x_k", hidden)?,
        ffn_key: matrix(
            tensors,
            "model.layers.0.ffn.key.weight",
            intermediate,
            hidden,
        )?,
        ffn_value: matrix(
            tensors,
            "model.layers.0.ffn.value.weight",
            hidden,
            intermediate,
        )?,
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
        let residual = layer_norm(
            embedding,
            &weights.pre_norm_weight,
            &weights.pre_norm_bias,
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

fn time_mix(
    weights: &LayerWeights,
    input: &[f32],
    previous: &[f32],
    state: &[f32],
    oracle_state: &[f32],
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
    let v = matvec(&weights.v_projection, &x_v)?;

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
        wkv_inputs: inputs,
        wkv_output: attention_output,
        oracle_output,
        matrix_state: next_state,
        oracle_state: next_oracle_state,
    })
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
