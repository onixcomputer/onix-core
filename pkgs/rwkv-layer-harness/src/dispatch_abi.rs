use super::*;
use serde::Serialize;

const DISPATCH_SCHEMA_VERSION: u32 = 1;
const DISPATCH_TARGET: &str = "rwkv_ttwkv7_dispatch_abi";
const MAGIC_WIDTH: usize = 8;
const REQUEST_MAGIC: [u8; MAGIC_WIDTH] = *b"RKW7REQ1";
const RESPONSE_MAGIC: [u8; MAGIC_WIDTH] = *b"RKW7RSP1";
const SEQUENCE_DOMAIN: &[u8] = b"rwkv-ttwkv7-dispatch-abi-sequence-v1";
const TRANSCRIPT_DOMAIN: &[u8] = b"rwkv-ttwkv7-dispatch-abi-transcript-v1";
const INPUT_ROLE_COUNT: usize = 6;
const ROLE_R: usize = 0;
const ROLE_W: usize = 1;
const ROLE_K: usize = 2;
const ROLE_V: usize = 3;
const ROLE_A: usize = 4;
const ROLE_B: usize = 5;
const FIXTURE_ROLE_OFFSET: usize = 2;
const DISPATCH_INPUT_ORDER: [&str; INPUT_ROLE_COUNT] = ["a", "w", "k", "v", "r", "b"];
const DISPATCH_TOKEN_COUNT: usize = 2;
const DISPATCH_CALL_COUNT: usize = MODEL_LAYER_COUNT * DISPATCH_TOKEN_COUNT;
const BF16_WIDTH: usize = 2;
const FRAME_ORDINAL_COUNT: usize = 3;
const FRAME_DIMENSION_COUNT: usize = 3;
const U32_WIDTH: usize = 4;
const SEQUENCE_ID_WIDTH: usize = 32;
pub(super) type DispatchSequenceId = [u8; SEQUENCE_ID_WIDTH];
const REQUEST_ID_WIDTH: usize = 32;
const FIXTURE_PERIOD: usize = 29;
const FIXTURE_CENTER: f32 = 14.0;
const FIXTURE_SCALE: f32 = 256.0;
const DECAY_BASE: f32 = 0.75;
const DECAY_SCALE: f32 = 2048.0;
const CONTROL_DIVERGENCE_FLOOR: f32 = 1.0e-7;
const NON_CLAIMS: [&str; 9] = [
    "The dispatch vectors are deterministic ABI fixtures, not model-derived vectors.",
    "The CPU emulator does not establish physical ttWKV7 execution.",
    "No process or persistent-process transport is established.",
    "No Metalium device is opened or initialized.",
    "No owner service is changed.",
    "No all-layer device execution or hardware token generation is established.",
    "No serving, throughput, or latency claim is established.",
    "The accepted physical session remains unsafe and is not reclassified.",
    "No new hardware execution is authorized by this receipt.",
];

#[derive(Clone, Debug)]
struct DispatchRequest {
    sequence_id: [u8; SEQUENCE_ID_WIDTH],
    call_ordinal: u32,
    token_ordinal: u32,
    layer_ordinal: u32,
    dimensions: Dimensions,
    inputs: WkvInputs,
    pre_state: Vec<f32>,
}

#[derive(Clone, Debug)]
struct DispatchResponse {
    sequence_id: [u8; SEQUENCE_ID_WIDTH],
    call_ordinal: u32,
    token_ordinal: u32,
    layer_ordinal: u32,
    dimensions: Dimensions,
    request_blake3: [u8; REQUEST_ID_WIDTH],
    raw_output: Vec<f32>,
    post_state: Vec<f32>,
}

#[derive(Clone, Debug, Serialize)]
pub struct Ttwkv7DispatchAbiReceipt {
    pub schema_version: u32,
    pub target: &'static str,
    pub dimensions: Dimensions,
    pub layer_count: usize,
    pub token_count: usize,
    pub call_count: usize,
    pub input_order: [&'static str; INPUT_ROLE_COUNT],
    pub sequence_id_blake3: String,
    pub request_frame_byte_count: usize,
    pub response_frame_byte_count: usize,
    pub ordered_request_blake3: Vec<String>,
    pub ordered_response_blake3: Vec<String>,
    pub transcript_blake3: String,
    pub retained_final_state_blake3: String,
    pub reset_final_state_blake3: String,
    pub transposed_final_state_blake3: String,
    pub retained_vs_reset_maximum_absolute_deviation: f32,
    pub retained_vs_transposed_maximum_absolute_deviation: f32,
    pub terminal_session_outcome: &'static str,
    pub physical_wkv_call_count: usize,
    pub non_claims: Vec<&'static str>,
}

#[derive(Clone, Copy)]
enum SecondTokenControl {
    Retained,
    Reset,
    Transposed,
}

struct DispatchReplay {
    request_frame_byte_count: usize,
    response_frame_byte_count: usize,
    request_blake3: Vec<String>,
    response_blake3: Vec<String>,
    transcript_blake3: String,
    final_state: Vec<f32>,
}

#[derive(Clone, Debug)]
pub(super) struct CpuDispatchStep {
    pub consumed_inputs: WkvInputs,
    pub consumed_pre_state: Vec<f32>,
    pub raw_output: Vec<f32>,
    pub post_state: Vec<f32>,
    pub request_frame: Vec<u8>,
    pub response_frame: Vec<u8>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum PersistentDispatchFault {
    Timeout,
    Interrupted,
    InvalidTransition,
    InvalidResponse,
}

impl PersistentDispatchFault {
    fn name(self) -> &'static str {
        match self {
            Self::Timeout => "timeout",
            Self::Interrupted => "interrupted",
            Self::InvalidTransition => "invalid_transition",
            Self::InvalidResponse => "invalid_response",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum PersistentDispatchLifecycle {
    Open,
    Faulted(PersistentDispatchFault),
    Closed,
}

#[derive(Clone, Debug)]
struct PendingDispatchCall {
    request: DispatchRequest,
    request_frame: Vec<u8>,
}

#[derive(Clone, Debug)]
pub(super) struct PersistentDispatchSessionSummary {
    pub sequence_id: String,
    pub first_token_index: usize,
    pub token_count: usize,
    pub call_count: usize,
    pub same_layer_state_continuity_count: usize,
    pub request_frame_byte_count: usize,
    pub response_frame_byte_count: usize,
    pub ordered_request_blake3: Vec<String>,
    pub ordered_response_blake3: Vec<String>,
    pub transcript_blake3: String,
    pub terminal_state: &'static str,
}

#[derive(Clone, Debug)]
pub(super) struct PersistentCpuDispatchSession {
    sequence_id: DispatchSequenceId,
    first_token_index: usize,
    token_count: usize,
    expected_call_count: usize,
    expected_same_layer_state_continuity_count: usize,
    next_call_ordinal: usize,
    lifecycle: PersistentDispatchLifecycle,
    pending: Option<PendingDispatchCall>,
    last_post_states: Vec<Option<Vec<f32>>>,
    accepted_steps: Vec<CpuDispatchStep>,
    same_layer_state_continuity_count: usize,
}

pub(super) struct DispatchTranscriptSummary {
    pub sequence_id: String,
    pub request_frame_byte_count: usize,
    pub response_frame_byte_count: usize,
    pub ordered_request_blake3: Vec<String>,
    pub ordered_response_blake3: Vec<String>,
    pub transcript_blake3: String,
}

struct FrameCursor<'a> {
    bytes: &'a [u8],
    offset: usize,
}

impl<'a> FrameCursor<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, offset: 0 }
    }

    fn take<const WIDTH: usize>(&mut self, name: &str) -> Result<[u8; WIDTH], String> {
        let end = self
            .offset
            .checked_add(WIDTH)
            .ok_or_else(|| format!("{name} offset overflow"))?;
        let source = self
            .bytes
            .get(self.offset..end)
            .ok_or_else(|| format!("{name} is truncated"))?;
        let mut result = [0_u8; WIDTH];
        result.copy_from_slice(source);
        self.offset = end;
        Ok(result)
    }

    fn u32(&mut self, name: &str) -> Result<u32, String> {
        Ok(u32::from_le_bytes(self.take::<U32_WIDTH>(name)?))
    }

    fn bf16_values(&mut self, count: usize, name: &str) -> Result<Vec<f32>, String> {
        let mut values = Vec::with_capacity(count);
        for _ in 0..count {
            let bits = u16::from_le_bytes(self.take::<BF16_WIDTH>(name)?);
            values.push(bf16::from_bits(bits).to_f32());
        }
        require_finite(&values, name)?;
        Ok(values)
    }

    fn finish(self, name: &str) -> Result<(), String> {
        if self.offset != self.bytes.len() {
            return Err(format!(
                "{name} has {} trailing bytes",
                self.bytes.len() - self.offset
            ));
        }
        Ok(())
    }
}

impl PersistentCpuDispatchSession {
    pub(super) fn new(
        sequence_id: DispatchSequenceId,
        first_token_index: usize,
        token_count: usize,
    ) -> Result<Self, String> {
        if token_count == 0 {
            return Err("persistent dispatch session requires at least one token".to_owned());
        }
        let expected_call_count = token_count
            .checked_mul(MODEL_LAYER_COUNT)
            .ok_or_else(|| "persistent dispatch call count overflow".to_owned())?;
        let expected_same_layer_state_continuity_count = (token_count - 1)
            .checked_mul(MODEL_LAYER_COUNT)
            .ok_or_else(|| "persistent dispatch continuity count overflow".to_owned())?;
        first_token_index
            .checked_add(token_count - 1)
            .ok_or_else(|| "persistent dispatch token index overflow".to_owned())?;
        Ok(Self {
            sequence_id,
            first_token_index,
            token_count,
            expected_call_count,
            expected_same_layer_state_continuity_count,
            next_call_ordinal: 0,
            lifecycle: PersistentDispatchLifecycle::Open,
            pending: None,
            last_post_states: vec![None; MODEL_LAYER_COUNT],
            accepted_steps: Vec::with_capacity(expected_call_count),
            same_layer_state_continuity_count: 0,
        })
    }

    pub(super) fn prepare(
        &mut self,
        token_index: usize,
        layer_index: usize,
        inputs: &WkvInputs,
        pre_state: &[f32],
    ) -> Result<Vec<u8>, String> {
        self.require_open("prepare")?;
        if self.pending.is_some() {
            return self.fail_transition("persistent dispatch already has a pending request");
        }
        if self.next_call_ordinal >= self.expected_call_count {
            return self.fail_transition("persistent dispatch received an extra request");
        }
        let expected_token = self
            .first_token_index
            .checked_add(self.next_call_ordinal / MODEL_LAYER_COUNT)
            .ok_or_else(|| "persistent dispatch token index overflow".to_owned())?;
        let expected_layer = self.next_call_ordinal % MODEL_LAYER_COUNT;
        if token_index != expected_token || layer_index != expected_layer {
            return self.fail_transition(&format!(
                "persistent dispatch request order mismatch: expected token {expected_token} layer {expected_layer}, found token {token_index} layer {layer_index}"
            ));
        }
        let request = DispatchRequest {
            sequence_id: self.sequence_id,
            call_ordinal: checked_u32(self.next_call_ordinal, "call ordinal")?,
            token_ordinal: checked_u32(token_index, "token ordinal")?,
            layer_ordinal: checked_u32(layer_index, "layer ordinal")?,
            dimensions: Dimensions::reviewed(),
            inputs: inputs.clone(),
            pre_state: pre_state.to_vec(),
        };
        let request_frame = encode_request(&request)?;
        let decoded_request = decode_request(&request_frame)?;
        validate_request_ordinals(
            &decoded_request,
            self.sequence_id,
            self.next_call_ordinal,
            token_index,
            layer_index,
        )?;
        if let Some(previous_post_state) = &self.last_post_states[layer_index] {
            if decoded_request.pre_state != *previous_post_state {
                return self.fail_transition(&format!(
                    "persistent dispatch layer {layer_index} pre-state does not equal its prior accepted post-state"
                ));
            }
            self.same_layer_state_continuity_count += 1;
        }
        self.pending = Some(PendingDispatchCall {
            request: decoded_request,
            request_frame: request_frame.clone(),
        });
        Ok(request_frame)
    }

    pub(super) fn accept(&mut self, response_frame: &[u8]) -> Result<CpuDispatchStep, String> {
        self.require_open("accept")?;
        let pending = match self.pending.as_ref() {
            Some(pending) => pending,
            None => {
                return self.fail_response(
                    "persistent dispatch received a response without a pending request",
                );
            }
        };
        let decoded_response = match decode_response(response_frame).and_then(|response| {
            validate_response(&pending.request, &pending.request_frame, &response)?;
            Ok(response)
        }) {
            Ok(response) => response,
            Err(error) => {
                return self.fail_response(&format!(
                    "persistent dispatch rejected pending response: {error}"
                ));
            }
        };
        let pending = self
            .pending
            .take()
            .ok_or_else(|| "persistent dispatch pending request disappeared".to_owned())?;
        let step = CpuDispatchStep {
            consumed_inputs: pending.request.inputs,
            consumed_pre_state: pending.request.pre_state,
            raw_output: decoded_response.raw_output,
            post_state: decoded_response.post_state,
            request_frame: pending.request_frame,
            response_frame: response_frame.to_vec(),
        };
        let layer_index = self.next_call_ordinal % MODEL_LAYER_COUNT;
        self.last_post_states[layer_index] = Some(step.post_state.clone());
        self.accepted_steps.push(step.clone());
        self.next_call_ordinal += 1;
        Ok(step)
    }

    pub(super) fn fault(&mut self, fault: PersistentDispatchFault) -> Result<(), String> {
        self.require_open("fault")?;
        self.lifecycle = PersistentDispatchLifecycle::Faulted(fault);
        Err(format!(
            "persistent dispatch session entered terminal {} fault",
            fault.name()
        ))
    }

    pub(super) fn close(&mut self) -> Result<PersistentDispatchSessionSummary, String> {
        self.require_open("close")?;
        if self.pending.is_some() {
            return self.fail_transition("persistent dispatch cannot close with a pending request");
        }
        if self.next_call_ordinal != self.expected_call_count {
            return self.fail_transition(&format!(
                "persistent dispatch cannot close after {} of {} calls",
                self.next_call_ordinal, self.expected_call_count
            ));
        }
        if self.last_post_states.iter().any(Option::is_none) {
            return self
                .fail_transition("persistent dispatch cannot close with missing layer state");
        }
        if self.same_layer_state_continuity_count != self.expected_same_layer_state_continuity_count
        {
            return self.fail_transition(&format!(
                "persistent dispatch continuity mismatch: expected {}, found {}",
                self.expected_same_layer_state_continuity_count,
                self.same_layer_state_continuity_count
            ));
        }
        let transcript = summarize_dispatch_steps(self.sequence_id, &self.accepted_steps)?;
        if transcript.ordered_request_blake3.len() != self.expected_call_count
            || transcript.ordered_response_blake3.len() != self.expected_call_count
        {
            return self.fail_transition("persistent dispatch transcript call count mismatch");
        }
        let unique_request_count = transcript
            .ordered_request_blake3
            .iter()
            .collect::<std::collections::BTreeSet<_>>()
            .len();
        let unique_response_count = transcript
            .ordered_response_blake3
            .iter()
            .collect::<std::collections::BTreeSet<_>>()
            .len();
        if unique_request_count != self.expected_call_count
            || unique_response_count != self.expected_call_count
        {
            return self
                .fail_transition("persistent dispatch transcript contains duplicate frames");
        }
        self.lifecycle = PersistentDispatchLifecycle::Closed;
        Ok(PersistentDispatchSessionSummary {
            sequence_id: transcript.sequence_id,
            first_token_index: self.first_token_index,
            token_count: self.token_count,
            call_count: self.expected_call_count,
            same_layer_state_continuity_count: self.same_layer_state_continuity_count,
            request_frame_byte_count: transcript.request_frame_byte_count,
            response_frame_byte_count: transcript.response_frame_byte_count,
            ordered_request_blake3: transcript.ordered_request_blake3,
            ordered_response_blake3: transcript.ordered_response_blake3,
            transcript_blake3: transcript.transcript_blake3,
            terminal_state: "closed",
        })
    }

    fn require_open(&self, action: &str) -> Result<(), String> {
        match self.lifecycle {
            PersistentDispatchLifecycle::Open => Ok(()),
            PersistentDispatchLifecycle::Faulted(fault) => Err(format!(
                "persistent dispatch {action} rejected after terminal {} fault",
                fault.name()
            )),
            PersistentDispatchLifecycle::Closed => Err(format!(
                "persistent dispatch {action} rejected after clean close"
            )),
        }
    }

    fn fail_transition<T>(&mut self, message: &str) -> Result<T, String> {
        self.lifecycle =
            PersistentDispatchLifecycle::Faulted(PersistentDispatchFault::InvalidTransition);
        Err(message.to_owned())
    }

    fn fail_response<T>(&mut self, message: &str) -> Result<T, String> {
        self.lifecycle =
            PersistentDispatchLifecycle::Faulted(PersistentDispatchFault::InvalidResponse);
        Err(message.to_owned())
    }
}

// r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_dispatch_abi]
pub fn run_ttwkv7_dispatch_abi_fixture() -> Result<Ttwkv7DispatchAbiReceipt, String> {
    let retained = execute_fixture(SecondTokenControl::Retained)?;
    let reset = execute_fixture(SecondTokenControl::Reset)?;
    let transposed = execute_fixture(SecondTokenControl::Transposed)?;
    let retained_vs_reset = max_abs_difference(&retained.final_state, &reset.final_state)?;
    let retained_vs_transposed =
        max_abs_difference(&retained.final_state, &transposed.final_state)?;
    if retained_vs_reset <= CONTROL_DIVERGENCE_FLOOR {
        return Err(format!(
            "retained/reset dispatch state divergence {retained_vs_reset} does not exceed {CONTROL_DIVERGENCE_FLOOR}"
        ));
    }
    if retained_vs_transposed <= CONTROL_DIVERGENCE_FLOOR {
        return Err(format!(
            "retained/transposed dispatch state divergence {retained_vs_transposed} does not exceed {CONTROL_DIVERGENCE_FLOOR}"
        ));
    }
    let sequence_id = sequence_id();
    Ok(Ttwkv7DispatchAbiReceipt {
        schema_version: DISPATCH_SCHEMA_VERSION,
        target: DISPATCH_TARGET,
        dimensions: Dimensions::reviewed(),
        layer_count: MODEL_LAYER_COUNT,
        token_count: DISPATCH_TOKEN_COUNT,
        call_count: DISPATCH_CALL_COUNT,
        input_order: DISPATCH_INPUT_ORDER,
        sequence_id_blake3: hex_bytes(&sequence_id),
        request_frame_byte_count: retained.request_frame_byte_count,
        response_frame_byte_count: retained.response_frame_byte_count,
        ordered_request_blake3: retained.request_blake3,
        ordered_response_blake3: retained.response_blake3,
        transcript_blake3: retained.transcript_blake3,
        retained_final_state_blake3: hash_f32(&retained.final_state),
        reset_final_state_blake3: hash_f32(&reset.final_state),
        transposed_final_state_blake3: hash_f32(&transposed.final_state),
        retained_vs_reset_maximum_absolute_deviation: retained_vs_reset,
        retained_vs_transposed_maximum_absolute_deviation: retained_vs_transposed,
        terminal_session_outcome: "unsafe",
        physical_wkv_call_count: 0,
        non_claims: NON_CLAIMS.to_vec(),
    })
}

fn execute_fixture(control: SecondTokenControl) -> Result<DispatchReplay, String> {
    let dimensions = Dimensions::reviewed();
    dimensions.validate()?;
    let state_count = dimensions.head_count * dimensions.head_size * dimensions.head_size;
    let sequence_id = sequence_id();
    let mut states = vec![vec![0.0_f32; state_count]; MODEL_LAYER_COUNT];
    let mut requests = Vec::with_capacity(DISPATCH_CALL_COUNT);
    let mut responses = Vec::with_capacity(DISPATCH_CALL_COUNT);
    let mut transcript = blake3::Hasher::new();
    transcript.update(TRANSCRIPT_DOMAIN);
    let mut request_frame_byte_count = None;
    let mut response_frame_byte_count = None;

    for token_ordinal in 0..DISPATCH_TOKEN_COUNT {
        if token_ordinal == 1 {
            apply_control(&mut states, control, dimensions)?;
        }
        for (layer_ordinal, state) in states.iter_mut().enumerate() {
            let call_ordinal = token_ordinal * MODEL_LAYER_COUNT + layer_ordinal;
            let request = fixture_request(
                sequence_id,
                call_ordinal,
                token_ordinal,
                layer_ordinal,
                state,
                dimensions,
            )?;
            let step = execute_cpu_dispatch_step(
                sequence_id,
                call_ordinal,
                token_ordinal,
                layer_ordinal,
                &request.inputs,
                &request.pre_state,
            )?;
            set_or_check_frame_size(
                &mut request_frame_byte_count,
                step.request_frame.len(),
                "request",
            )?;
            set_or_check_frame_size(
                &mut response_frame_byte_count,
                step.response_frame.len(),
                "response",
            )?;
            state.clone_from(&step.post_state);
            let request_hash = blake3::hash(&step.request_frame);
            let response_hash = blake3::hash(&step.response_frame);
            requests.push(request_hash.to_hex().to_string());
            responses.push(response_hash.to_hex().to_string());
            update_transcript(&mut transcript, &step.request_frame, &step.response_frame)?;
        }
    }
    if requests.len() != DISPATCH_CALL_COUNT || responses.len() != DISPATCH_CALL_COUNT {
        return Err(format!(
            "dispatch transcript requires {DISPATCH_CALL_COUNT} calls, found {}/{}",
            requests.len(),
            responses.len()
        ));
    }
    let final_state = states.into_iter().flatten().collect::<Vec<_>>();
    require_finite(&final_state, "dispatch final state")?;
    Ok(DispatchReplay {
        request_frame_byte_count: request_frame_byte_count
            .ok_or_else(|| "request frame size was not recorded".to_owned())?,
        response_frame_byte_count: response_frame_byte_count
            .ok_or_else(|| "response frame size was not recorded".to_owned())?,
        request_blake3: requests,
        response_blake3: responses,
        transcript_blake3: transcript.finalize().to_hex().to_string(),
        final_state,
    })
}

fn apply_control(
    states: &mut [Vec<f32>],
    control: SecondTokenControl,
    dimensions: Dimensions,
) -> Result<(), String> {
    match control {
        SecondTokenControl::Retained => Ok(()),
        SecondTokenControl::Reset => {
            for state in states {
                state.fill(0.0);
            }
            Ok(())
        }
        SecondTokenControl::Transposed => {
            for state in states {
                *state = super::observed_layer::transpose_head_matrices(state, dimensions)?;
            }
            Ok(())
        }
    }
}

fn fixture_request(
    sequence_id: [u8; SEQUENCE_ID_WIDTH],
    call_ordinal: usize,
    token_ordinal: usize,
    layer_ordinal: usize,
    pre_state: &[f32],
    dimensions: Dimensions,
) -> Result<DispatchRequest, String> {
    let inputs = WkvInputs {
        r: fixture_vector(token_ordinal, layer_ordinal, ROLE_R, dimensions, false),
        w: fixture_vector(token_ordinal, layer_ordinal, ROLE_W, dimensions, true),
        k: fixture_vector(token_ordinal, layer_ordinal, ROLE_K, dimensions, false),
        v: fixture_vector(token_ordinal, layer_ordinal, ROLE_V, dimensions, false),
        a: fixture_vector(token_ordinal, layer_ordinal, ROLE_A, dimensions, false),
        b: fixture_vector(token_ordinal, layer_ordinal, ROLE_B, dimensions, false),
    };
    validate_wkv_shapes(pre_state, &inputs, dimensions)?;
    Ok(DispatchRequest {
        sequence_id,
        call_ordinal: checked_u32(call_ordinal, "call ordinal")?,
        token_ordinal: checked_u32(token_ordinal, "token ordinal")?,
        layer_ordinal: checked_u32(layer_ordinal, "layer ordinal")?,
        dimensions,
        inputs,
        pre_state: pre_state.to_vec(),
    })
}

fn fixture_vector(
    token: usize,
    layer: usize,
    role: usize,
    dimensions: Dimensions,
    decay: bool,
) -> Vec<f32> {
    (0..dimensions.hidden_size)
        .map(|index| {
            let mixed =
                ((token + 1) * (role + FIXTURE_ROLE_OFFSET) * ((index % FIXTURE_PERIOD) + 1)
                    + layer
                    + role)
                    % FIXTURE_PERIOD;
            let value = if decay {
                DECAY_BASE + mixed as f32 / DECAY_SCALE
            } else {
                (mixed as f32 - FIXTURE_CENTER) / FIXTURE_SCALE
            };
            bf16::from_f32(value).to_f32()
        })
        .collect()
}

fn encode_request(request: &DispatchRequest) -> Result<Vec<u8>, String> {
    validate_request_payload(request)?;
    let mut bytes = Vec::with_capacity(request_frame_size(request.dimensions));
    bytes.extend_from_slice(&REQUEST_MAGIC);
    push_u32(&mut bytes, DISPATCH_SCHEMA_VERSION);
    bytes.extend_from_slice(&request.sequence_id);
    push_frame_metadata(
        &mut bytes,
        request.call_ordinal,
        request.token_ordinal,
        request.layer_ordinal,
        request.dimensions,
    )?;
    for values in request_input_vectors(&request.inputs) {
        push_bf16_values(&mut bytes, values, "request input")?;
    }
    push_bf16_values(&mut bytes, &request.pre_state, "request pre-state")?;
    Ok(bytes)
}

fn decode_request(bytes: &[u8]) -> Result<DispatchRequest, String> {
    let mut cursor = FrameCursor::new(bytes);
    let magic = cursor.take::<MAGIC_WIDTH>("request magic")?;
    if magic != REQUEST_MAGIC {
        return Err("request magic mismatch".to_owned());
    }
    validate_version(cursor.u32("request schema version")?)?;
    let sequence_id = cursor.take::<SEQUENCE_ID_WIDTH>("request sequence id")?;
    let (call_ordinal, token_ordinal, layer_ordinal, dimensions) =
        decode_frame_metadata(&mut cursor, "request")?;
    let hidden = dimensions.hidden_size;
    let inputs = WkvInputs {
        a: cursor.bf16_values(hidden, "request a")?,
        w: cursor.bf16_values(hidden, "request w")?,
        k: cursor.bf16_values(hidden, "request k")?,
        v: cursor.bf16_values(hidden, "request v")?,
        r: cursor.bf16_values(hidden, "request r")?,
        b: cursor.bf16_values(hidden, "request b")?,
    };
    let state_count = dimensions.head_count * dimensions.head_size * dimensions.head_size;
    let pre_state = cursor.bf16_values(state_count, "request pre-state")?;
    cursor.finish("request frame")?;
    let request = DispatchRequest {
        sequence_id,
        call_ordinal,
        token_ordinal,
        layer_ordinal,
        dimensions,
        inputs,
        pre_state,
    };
    validate_request_payload(&request)?;
    Ok(request)
}

fn encode_response(response: &DispatchResponse) -> Result<Vec<u8>, String> {
    validate_response_payload(response)?;
    let mut bytes = Vec::with_capacity(response_frame_size(response.dimensions));
    bytes.extend_from_slice(&RESPONSE_MAGIC);
    push_u32(&mut bytes, DISPATCH_SCHEMA_VERSION);
    bytes.extend_from_slice(&response.sequence_id);
    push_frame_metadata(
        &mut bytes,
        response.call_ordinal,
        response.token_ordinal,
        response.layer_ordinal,
        response.dimensions,
    )?;
    bytes.extend_from_slice(&response.request_blake3);
    push_bf16_values(&mut bytes, &response.raw_output, "response raw output")?;
    push_bf16_values(&mut bytes, &response.post_state, "response post-state")?;
    Ok(bytes)
}

fn decode_response(bytes: &[u8]) -> Result<DispatchResponse, String> {
    let mut cursor = FrameCursor::new(bytes);
    let magic = cursor.take::<MAGIC_WIDTH>("response magic")?;
    if magic != RESPONSE_MAGIC {
        return Err("response magic mismatch".to_owned());
    }
    validate_version(cursor.u32("response schema version")?)?;
    let sequence_id = cursor.take::<SEQUENCE_ID_WIDTH>("response sequence id")?;
    let (call_ordinal, token_ordinal, layer_ordinal, dimensions) =
        decode_frame_metadata(&mut cursor, "response")?;
    let request_blake3 = cursor.take::<REQUEST_ID_WIDTH>("response request identity")?;
    let raw_output = cursor.bf16_values(dimensions.hidden_size, "response raw output")?;
    let state_count = dimensions.head_count * dimensions.head_size * dimensions.head_size;
    let post_state = cursor.bf16_values(state_count, "response post-state")?;
    cursor.finish("response frame")?;
    let response = DispatchResponse {
        sequence_id,
        call_ordinal,
        token_ordinal,
        layer_ordinal,
        dimensions,
        request_blake3,
        raw_output,
        post_state,
    };
    validate_response_payload(&response)?;
    Ok(response)
}

fn emulate_cpu_response(
    request: &DispatchRequest,
    request_frame: &[u8],
) -> Result<DispatchResponse, String> {
    let (post_state, raw_output) =
        wkv_step_matrix(&request.pre_state, &request.inputs, request.dimensions)?;
    Ok(DispatchResponse {
        sequence_id: request.sequence_id,
        call_ordinal: request.call_ordinal,
        token_ordinal: request.token_ordinal,
        layer_ordinal: request.layer_ordinal,
        dimensions: request.dimensions,
        request_blake3: *blake3::hash(request_frame).as_bytes(),
        raw_output: quantize_bf16_values(&raw_output, "dispatch raw output")?,
        post_state: quantize_bf16_values(&post_state, "dispatch post-state")?,
    })
}

fn validate_request_ordinals(
    request: &DispatchRequest,
    sequence_id: [u8; SEQUENCE_ID_WIDTH],
    call: usize,
    token: usize,
    layer: usize,
) -> Result<(), String> {
    if request.sequence_id != sequence_id {
        return Err("request sequence identity mismatch".to_owned());
    }
    for (actual, expected, name) in [
        (
            request.call_ordinal,
            checked_u32(call, "call ordinal")?,
            "call",
        ),
        (
            request.token_ordinal,
            checked_u32(token, "token ordinal")?,
            "token",
        ),
        (
            request.layer_ordinal,
            checked_u32(layer, "layer ordinal")?,
            "layer",
        ),
    ] {
        if actual != expected {
            return Err(format!(
                "request {name} ordinal mismatch: expected {expected}, found {actual}"
            ));
        }
    }
    Ok(())
}

fn validate_response(
    request: &DispatchRequest,
    request_frame: &[u8],
    response: &DispatchResponse,
) -> Result<(), String> {
    validate_response_payload(response)?;
    if response.sequence_id != request.sequence_id
        || response.call_ordinal != request.call_ordinal
        || response.token_ordinal != request.token_ordinal
        || response.layer_ordinal != request.layer_ordinal
        || response.dimensions != request.dimensions
    {
        return Err("response authority does not match request".to_owned());
    }
    let expected = blake3::hash(request_frame);
    if response.request_blake3 != *expected.as_bytes() {
        return Err("response request identity mismatch".to_owned());
    }
    Ok(())
}

fn validate_request_payload(request: &DispatchRequest) -> Result<(), String> {
    if request.dimensions != Dimensions::reviewed() {
        return Err("request dimensions do not match reviewed dimensions".to_owned());
    }
    if request.layer_ordinal as usize >= MODEL_LAYER_COUNT {
        return Err(format!(
            "request layer ordinal {} is outside {MODEL_LAYER_COUNT} layers",
            request.layer_ordinal
        ));
    }
    validate_wkv_shapes(&request.pre_state, &request.inputs, request.dimensions)
}

fn validate_response_payload(response: &DispatchResponse) -> Result<(), String> {
    if response.dimensions != Dimensions::reviewed() {
        return Err("response dimensions do not match reviewed dimensions".to_owned());
    }
    if response.layer_ordinal as usize >= MODEL_LAYER_COUNT {
        return Err(format!(
            "response layer ordinal {} is outside {MODEL_LAYER_COUNT} layers",
            response.layer_ordinal
        ));
    }
    require_length(
        &response.raw_output,
        response.dimensions.hidden_size,
        "response raw output",
    )?;
    require_length(
        &response.post_state,
        response.dimensions.head_count
            * response.dimensions.head_size
            * response.dimensions.head_size,
        "response post-state",
    )?;
    require_finite(&response.raw_output, "response raw output")?;
    require_finite(&response.post_state, "response post-state")
}

fn push_frame_metadata(
    bytes: &mut Vec<u8>,
    call: u32,
    token: u32,
    layer: u32,
    dimensions: Dimensions,
) -> Result<(), String> {
    for value in [
        call,
        token,
        layer,
        checked_u32(dimensions.head_count, "head count")?,
        checked_u32(dimensions.head_size, "head size")?,
        checked_u32(dimensions.hidden_size, "hidden size")?,
    ] {
        push_u32(bytes, value);
    }
    Ok(())
}

fn decode_frame_metadata(
    cursor: &mut FrameCursor<'_>,
    name: &str,
) -> Result<(u32, u32, u32, Dimensions), String> {
    let call = cursor.u32(&format!("{name} call ordinal"))?;
    let token = cursor.u32(&format!("{name} token ordinal"))?;
    let layer = cursor.u32(&format!("{name} layer ordinal"))?;
    let head_count = cursor.u32(&format!("{name} head count"))? as usize;
    let head_size = cursor.u32(&format!("{name} head size"))? as usize;
    let hidden_size = cursor.u32(&format!("{name} hidden size"))? as usize;
    let reviewed = Dimensions::reviewed();
    let dimensions = Dimensions {
        hidden_size,
        head_size,
        head_count,
        intermediate_size: reviewed.intermediate_size,
    };
    if dimensions != reviewed {
        return Err(format!(
            "{name} dimensions do not match reviewed dimensions"
        ));
    }
    Ok((call, token, layer, dimensions))
}

fn request_input_vectors(inputs: &WkvInputs) -> [&[f32]; INPUT_ROLE_COUNT] {
    [
        &inputs.a, &inputs.w, &inputs.k, &inputs.v, &inputs.r, &inputs.b,
    ]
}

fn push_bf16_values(bytes: &mut Vec<u8>, values: &[f32], name: &str) -> Result<(), String> {
    require_finite(values, name)?;
    for value in values {
        bytes.extend_from_slice(&bf16::from_f32(*value).to_bits().to_le_bytes());
    }
    Ok(())
}

fn push_u32(bytes: &mut Vec<u8>, value: u32) {
    bytes.extend_from_slice(&value.to_le_bytes());
}

fn validate_version(version: u32) -> Result<(), String> {
    if version != DISPATCH_SCHEMA_VERSION {
        return Err(format!(
            "dispatch schema version mismatch: expected {DISPATCH_SCHEMA_VERSION}, found {version}"
        ));
    }
    Ok(())
}

fn checked_u32(value: usize, name: &str) -> Result<u32, String> {
    u32::try_from(value).map_err(|_| format!("{name} {value} does not fit u32"))
}

fn request_frame_size(dimensions: Dimensions) -> usize {
    REQUEST_MAGIC.len()
        + U32_WIDTH
        + SEQUENCE_ID_WIDTH
        + (FRAME_ORDINAL_COUNT + FRAME_DIMENSION_COUNT) * U32_WIDTH
        + (INPUT_ROLE_COUNT * dimensions.hidden_size
            + dimensions.head_count * dimensions.head_size * dimensions.head_size)
            * BF16_WIDTH
}

fn response_frame_size(dimensions: Dimensions) -> usize {
    RESPONSE_MAGIC.len()
        + U32_WIDTH
        + SEQUENCE_ID_WIDTH
        + (FRAME_ORDINAL_COUNT + FRAME_DIMENSION_COUNT) * U32_WIDTH
        + REQUEST_ID_WIDTH
        + (dimensions.hidden_size
            + dimensions.head_count * dimensions.head_size * dimensions.head_size)
            * BF16_WIDTH
}

fn set_or_check_frame_size(
    recorded: &mut Option<usize>,
    actual: usize,
    name: &str,
) -> Result<(), String> {
    match recorded {
        Some(expected) if *expected != actual => Err(format!(
            "{name} frame size changed: expected {expected}, found {actual}"
        )),
        Some(_) => Ok(()),
        None => {
            *recorded = Some(actual);
            Ok(())
        }
    }
}

fn update_transcript(
    transcript: &mut blake3::Hasher,
    request: &[u8],
    response: &[u8],
) -> Result<(), String> {
    let request_len = u64::try_from(request.len())
        .map_err(|_| "request frame length does not fit u64".to_owned())?;
    let response_len = u64::try_from(response.len())
        .map_err(|_| "response frame length does not fit u64".to_owned())?;
    transcript.update(&request_len.to_le_bytes());
    transcript.update(request);
    transcript.update(&response_len.to_le_bytes());
    transcript.update(response);
    Ok(())
}

pub(super) fn execute_cpu_dispatch_step(
    sequence_id: DispatchSequenceId,
    call_ordinal: usize,
    token_ordinal: usize,
    layer_ordinal: usize,
    inputs: &WkvInputs,
    pre_state: &[f32],
) -> Result<CpuDispatchStep, String> {
    let dimensions = Dimensions::reviewed();
    let request = DispatchRequest {
        sequence_id,
        call_ordinal: checked_u32(call_ordinal, "call ordinal")?,
        token_ordinal: checked_u32(token_ordinal, "token ordinal")?,
        layer_ordinal: checked_u32(layer_ordinal, "layer ordinal")?,
        dimensions,
        inputs: inputs.clone(),
        pre_state: pre_state.to_vec(),
    };
    let request_frame = encode_request(&request)?;
    let decoded_request = decode_request(&request_frame)?;
    validate_request_ordinals(
        &decoded_request,
        sequence_id,
        call_ordinal,
        token_ordinal,
        layer_ordinal,
    )?;
    let response = emulate_cpu_response(&decoded_request, &request_frame)?;
    let response_frame = encode_response(&response)?;
    let decoded_response = decode_response(&response_frame)?;
    validate_response(&decoded_request, &request_frame, &decoded_response)?;
    Ok(CpuDispatchStep {
        consumed_inputs: decoded_request.inputs,
        consumed_pre_state: decoded_request.pre_state,
        raw_output: decoded_response.raw_output,
        post_state: decoded_response.post_state,
        request_frame,
        response_frame,
    })
}

pub(super) fn emulate_cpu_response_frame(request_frame: &[u8]) -> Result<Vec<u8>, String> {
    let request = decode_request(request_frame)?;
    let response = emulate_cpu_response(&request, request_frame)?;
    encode_response(&response)
}

pub(super) fn execute_persistent_cpu_dispatch_step(
    session: &mut PersistentCpuDispatchSession,
    token_index: usize,
    layer_index: usize,
    inputs: &WkvInputs,
    pre_state: &[f32],
) -> Result<CpuDispatchStep, String> {
    let request_frame = session.prepare(token_index, layer_index, inputs, pre_state)?;
    let response_frame = emulate_cpu_response_frame(&request_frame)?;
    session.accept(&response_frame)
}

pub(super) fn summarize_dispatch_steps(
    sequence_id: DispatchSequenceId,
    steps: &[CpuDispatchStep],
) -> Result<DispatchTranscriptSummary, String> {
    if steps.is_empty() {
        return Err("dispatch transcript requires at least one step".to_owned());
    }
    let mut request_frame_byte_count = None;
    let mut response_frame_byte_count = None;
    let mut ordered_request_blake3 = Vec::with_capacity(steps.len());
    let mut ordered_response_blake3 = Vec::with_capacity(steps.len());
    let mut transcript = blake3::Hasher::new();
    transcript.update(TRANSCRIPT_DOMAIN);
    for step in steps {
        set_or_check_frame_size(
            &mut request_frame_byte_count,
            step.request_frame.len(),
            "request",
        )?;
        set_or_check_frame_size(
            &mut response_frame_byte_count,
            step.response_frame.len(),
            "response",
        )?;
        ordered_request_blake3.push(blake3::hash(&step.request_frame).to_hex().to_string());
        ordered_response_blake3.push(blake3::hash(&step.response_frame).to_hex().to_string());
        update_transcript(&mut transcript, &step.request_frame, &step.response_frame)?;
    }
    Ok(DispatchTranscriptSummary {
        sequence_id: hex_bytes(&sequence_id),
        request_frame_byte_count: request_frame_byte_count
            .ok_or_else(|| "request frame size was not recorded".to_owned())?,
        response_frame_byte_count: response_frame_byte_count
            .ok_or_else(|| "response frame size was not recorded".to_owned())?,
        ordered_request_blake3,
        ordered_response_blake3,
        transcript_blake3: transcript.finalize().to_hex().to_string(),
    })
}

pub(super) fn derive_sequence_id(domain: &[u8]) -> DispatchSequenceId {
    *blake3::hash(domain).as_bytes()
}

fn sequence_id() -> [u8; SEQUENCE_ID_WIDTH] {
    derive_sequence_id(SEQUENCE_DOMAIN)
}

fn hash_f32(values: &[f32]) -> String {
    let mut hasher = blake3::Hasher::new();
    for value in values {
        hasher.update(&value.to_bits().to_le_bytes());
    }
    hasher.finalize().to_hex().to_string()
}

fn hex_bytes(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const VERSION_OFFSET: usize = REQUEST_MAGIC.len();
    const SEQUENCE_OFFSET: usize = VERSION_OFFSET + U32_WIDTH;
    const CALL_OFFSET: usize = SEQUENCE_OFFSET + SEQUENCE_ID_WIDTH;
    const HEAD_COUNT_OFFSET: usize = CALL_OFFSET + FRAME_ORDINAL_COUNT * U32_WIDTH;
    const REQUEST_PAYLOAD_OFFSET: usize = HEAD_COUNT_OFFSET + FRAME_DIMENSION_COUNT * U32_WIDTH;
    const RESPONSE_PAYLOAD_OFFSET: usize = REQUEST_PAYLOAD_OFFSET + REQUEST_ID_WIDTH;

    const PERSISTENT_FIRST_TOKEN_INDEX: usize = 2;
    const PERSISTENT_TOKEN_COUNT: usize = 2;
    const PERSISTENT_SINGLE_TOKEN_COUNT: usize = 1;
    const PERSISTENT_CALL_COUNT: usize = MODEL_LAYER_COUNT * PERSISTENT_TOKEN_COUNT;
    const PERSISTENT_SEQUENCE_DOMAIN: &[u8] = b"rwkv-ttwkv7-persistent-session-test-v1";

    fn first_request() -> DispatchRequest {
        let dimensions = Dimensions::reviewed();
        let state_count = dimensions.head_count * dimensions.head_size * dimensions.head_size;
        fixture_request(sequence_id(), 0, 0, 0, &vec![0.0; state_count], dimensions)
            .expect("fixture request must succeed")
    }

    fn persistent_fixture_inputs(token_index: usize, layer_index: usize) -> WkvInputs {
        let dimensions = Dimensions::reviewed();
        let state_count = dimensions.head_count * dimensions.head_size * dimensions.head_size;
        fixture_request(
            derive_sequence_id(PERSISTENT_SEQUENCE_DOMAIN),
            0,
            token_index,
            layer_index,
            &vec![0.0; state_count],
            dimensions,
        )
        .expect("persistent fixture request must succeed")
        .inputs
    }

    fn persistent_zero_states() -> Vec<Vec<f32>> {
        let dimensions = Dimensions::reviewed();
        let state_count = dimensions.head_count * dimensions.head_size * dimensions.head_size;
        vec![vec![0.0; state_count]; MODEL_LAYER_COUNT]
    }

    fn execute_persistent_fixture_token(
        session: &mut PersistentCpuDispatchSession,
        token_index: usize,
        states: &mut [Vec<f32>],
    ) {
        for (layer_index, state) in states.iter_mut().enumerate() {
            let inputs = persistent_fixture_inputs(token_index, layer_index);
            let step = execute_persistent_cpu_dispatch_step(
                session,
                token_index,
                layer_index,
                &inputs,
                state,
            )
            .expect("persistent fixture step must succeed");
            state.clone_from(&step.post_state);
        }
    }

    #[test]
    fn dispatch_frames_round_trip_and_bind_response() {
        let request = first_request();
        let request_frame = encode_request(&request).expect("request encoding must succeed");
        assert_eq!(request_frame.len(), request_frame_size(request.dimensions));
        let decoded = decode_request(&request_frame).expect("request decoding must succeed");
        let response =
            emulate_cpu_response(&decoded, &request_frame).expect("CPU response must succeed");
        let response_frame = encode_response(&response).expect("response encoding must succeed");
        assert_eq!(
            response_frame.len(),
            response_frame_size(response.dimensions)
        );
        let decoded_response =
            decode_response(&response_frame).expect("response decoding must succeed");
        validate_response(&decoded, &request_frame, &decoded_response)
            .expect("response must bind to request");
    }

    #[test]
    fn request_decoder_rejects_authority_and_shape_mutations() {
        let request = first_request();
        let frame = encode_request(&request).expect("request encoding must succeed");
        for (offset, name) in [
            (0, "magic"),
            (VERSION_OFFSET, "version"),
            (HEAD_COUNT_OFFSET, "dimensions"),
        ] {
            let mut changed = frame.clone();
            changed[offset] ^= 1;
            assert!(
                decode_request(&changed).is_err(),
                "changed {name} must be rejected"
            );
        }
        assert!(decode_request(&frame[..frame.len() - 1]).is_err());
        let mut trailing = frame.clone();
        trailing.push(0);
        assert!(decode_request(&trailing).is_err());
        let mut non_finite = frame;
        non_finite[REQUEST_PAYLOAD_OFFSET..REQUEST_PAYLOAD_OFFSET + BF16_WIDTH]
            .copy_from_slice(&bf16::NAN.to_bits().to_le_bytes());
        assert!(decode_request(&non_finite).is_err());
    }

    #[test]
    fn response_decoder_rejects_authority_and_shape_mutations() {
        let request = first_request();
        let request_frame = encode_request(&request).expect("request encoding must succeed");
        let response = emulate_cpu_response(&request, &request_frame)
            .expect("CPU response emulation must succeed");
        let frame = encode_response(&response).expect("response encoding must succeed");
        for (offset, name) in [
            (0, "magic"),
            (VERSION_OFFSET, "version"),
            (HEAD_COUNT_OFFSET, "dimensions"),
        ] {
            let mut changed = frame.clone();
            changed[offset] ^= 1;
            assert!(
                decode_response(&changed).is_err(),
                "changed response {name} must be rejected"
            );
        }
        assert!(decode_response(&frame[..frame.len() - 1]).is_err());
        let mut trailing = frame.clone();
        trailing.push(0);
        assert!(decode_response(&trailing).is_err());
        let mut non_finite = frame;
        non_finite[RESPONSE_PAYLOAD_OFFSET..RESPONSE_PAYLOAD_OFFSET + BF16_WIDTH]
            .copy_from_slice(&bf16::NAN.to_bits().to_le_bytes());
        assert!(decode_response(&non_finite).is_err());
    }

    #[test]
    fn ordinal_and_response_mutations_fail_closed() {
        let request = first_request();
        let frame = encode_request(&request).expect("request encoding must succeed");
        let decoded = decode_request(&frame).expect("request decoding must succeed");
        assert!(validate_request_ordinals(&decoded, sequence_id(), 1, 0, 0).is_err());
        let mut changed_sequence = sequence_id();
        changed_sequence[0] ^= 1;
        assert!(validate_request_ordinals(&decoded, changed_sequence, 0, 0, 0).is_err());
        let mut response =
            emulate_cpu_response(&decoded, &frame).expect("CPU response must succeed");
        response.call_ordinal += 1;
        assert!(validate_response(&decoded, &frame, &response).is_err());
        response.call_ordinal = decoded.call_ordinal;
        response.request_blake3[0] ^= 1;
        assert!(validate_response(&decoded, &frame, &response).is_err());
        let mut changed_frame = frame;
        changed_frame[CALL_OFFSET] ^= 1;
        assert!(validate_response(&decoded, &changed_frame, &response).is_err());
    }

    #[test]
    fn persistent_session_completes_two_tokens_with_same_layer_state_continuity() {
        let sequence_id = derive_sequence_id(PERSISTENT_SEQUENCE_DOMAIN);
        let mut session = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("persistent session must open");
        let mut states = persistent_zero_states();
        execute_persistent_fixture_token(&mut session, PERSISTENT_FIRST_TOKEN_INDEX, &mut states);
        execute_persistent_fixture_token(
            &mut session,
            PERSISTENT_FIRST_TOKEN_INDEX + 1,
            &mut states,
        );
        let summary = session.close().expect("persistent session must close");
        assert_eq!(summary.call_count, PERSISTENT_CALL_COUNT);
        assert_eq!(summary.token_count, PERSISTENT_TOKEN_COUNT);
        assert_eq!(summary.first_token_index, PERSISTENT_FIRST_TOKEN_INDEX);
        assert_eq!(summary.same_layer_state_continuity_count, MODEL_LAYER_COUNT);
        assert_eq!(summary.ordered_request_blake3.len(), PERSISTENT_CALL_COUNT);
        assert_eq!(summary.ordered_response_blake3.len(), PERSISTENT_CALL_COUNT);
        assert_eq!(summary.terminal_state, "closed");
        let inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX, 0);
        assert!(
            session
                .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
                .is_err()
        );
    }

    #[test]
    fn persistent_session_rejects_order_and_same_layer_state_drift() {
        let sequence_id = derive_sequence_id(PERSISTENT_SEQUENCE_DOMAIN);
        let mut wrong_order = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("wrong-order session must open");
        let states = persistent_zero_states();
        let wrong_inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX, 1);
        assert!(
            wrong_order
                .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 1, &wrong_inputs, &states[1])
                .is_err()
        );
        let first_inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX, 0);
        assert!(
            wrong_order
                .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &first_inputs, &states[0])
                .is_err()
        );

        let mut changed_state = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("changed-state session must open");
        let mut carried_states = persistent_zero_states();
        execute_persistent_fixture_token(
            &mut changed_state,
            PERSISTENT_FIRST_TOKEN_INDEX,
            &mut carried_states,
        );
        carried_states[0][0] += 1.0;
        let next_inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX + 1, 0);
        assert!(
            changed_state
                .prepare(
                    PERSISTENT_FIRST_TOKEN_INDEX + 1,
                    0,
                    &next_inputs,
                    &carried_states[0]
                )
                .is_err()
        );
        assert!(changed_state.close().is_err());
    }

    #[test]
    fn persistent_session_rejects_stale_truncated_and_duplicate_responses() {
        let sequence_id = derive_sequence_id(PERSISTENT_SEQUENCE_DOMAIN);
        let states = persistent_zero_states();
        let inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX, 0);

        let mut stale = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("stale-response session must open");
        let request = stale
            .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
            .expect("stale-response request must prepare");
        let mut stale_response =
            emulate_cpu_response_frame(&request).expect("response emulation must succeed");
        stale_response[CALL_OFFSET] ^= 1;
        assert!(stale.accept(&stale_response).is_err());
        assert!(stale.accept(&stale_response).is_err());

        let mut truncated = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("truncated-response session must open");
        let request = truncated
            .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
            .expect("truncated-response request must prepare");
        let response =
            emulate_cpu_response_frame(&request).expect("response emulation must succeed");
        assert!(truncated.accept(&response[..response.len() - 1]).is_err());
        assert!(truncated.close().is_err());

        let mut duplicate = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("duplicate-response session must open");
        let request = duplicate
            .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
            .expect("duplicate-response request must prepare");
        let response =
            emulate_cpu_response_frame(&request).expect("response emulation must succeed");
        duplicate
            .accept(&response)
            .expect("first response must be accepted");
        assert!(duplicate.accept(&response).is_err());
        assert!(duplicate.close().is_err());
    }

    #[test]
    fn persistent_session_rejects_parallel_pending_calls_and_extra_calls() {
        let sequence_id = derive_sequence_id(PERSISTENT_SEQUENCE_DOMAIN);
        let states = persistent_zero_states();
        let inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX, 0);
        let mut pending = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("pending-call session must open");
        pending
            .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
            .expect("first pending request must prepare");
        assert!(
            pending
                .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
                .is_err()
        );
        assert!(pending.close().is_err());

        let mut extra = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_SINGLE_TOKEN_COUNT,
        )
        .expect("extra-call session must open");
        let mut carried_states = persistent_zero_states();
        execute_persistent_fixture_token(
            &mut extra,
            PERSISTENT_FIRST_TOKEN_INDEX,
            &mut carried_states,
        );
        let extra_inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX + 1, 0);
        assert!(
            extra
                .prepare(
                    PERSISTENT_FIRST_TOKEN_INDEX + 1,
                    0,
                    &extra_inputs,
                    &carried_states[0]
                )
                .is_err()
        );
        assert!(extra.close().is_err());
    }

    #[test]
    fn persistent_session_timeout_interruption_and_premature_close_are_terminal() {
        let sequence_id = derive_sequence_id(PERSISTENT_SEQUENCE_DOMAIN);
        let states = persistent_zero_states();
        let inputs = persistent_fixture_inputs(PERSISTENT_FIRST_TOKEN_INDEX, 0);

        let mut timed_out = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("timeout session must open");
        let request = timed_out
            .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
            .expect("timeout request must prepare");
        let response =
            emulate_cpu_response_frame(&request).expect("response emulation must succeed");
        assert!(timed_out.fault(PersistentDispatchFault::Timeout).is_err());
        assert!(timed_out.accept(&response).is_err());
        assert!(timed_out.close().is_err());

        let mut interrupted = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("interrupted session must open");
        assert!(
            interrupted
                .fault(PersistentDispatchFault::Interrupted)
                .is_err()
        );
        assert!(
            interrupted
                .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
                .is_err()
        );

        let mut premature_close = PersistentCpuDispatchSession::new(
            sequence_id,
            PERSISTENT_FIRST_TOKEN_INDEX,
            PERSISTENT_TOKEN_COUNT,
        )
        .expect("premature-close session must open");
        assert!(premature_close.close().is_err());
        assert!(
            premature_close
                .prepare(PERSISTENT_FIRST_TOKEN_INDEX, 0, &inputs, &states[0])
                .is_err()
        );
    }

    #[test]
    fn retained_fixture_is_deterministic_and_controls_diverge() {
        let first = run_ttwkv7_dispatch_abi_fixture().expect("first replay must succeed");
        let second = run_ttwkv7_dispatch_abi_fixture().expect("second replay must succeed");
        let first_json = serde_json::to_vec(&first).expect("first receipt must serialize");
        let second_json = serde_json::to_vec(&second).expect("second receipt must serialize");
        assert_eq!(first_json, second_json);
        assert_eq!(first.call_count, DISPATCH_CALL_COUNT);
        assert!(first.retained_vs_reset_maximum_absolute_deviation > CONTROL_DIVERGENCE_FLOOR);
        assert!(first.retained_vs_transposed_maximum_absolute_deviation > CONTROL_DIVERGENCE_FLOOR);
    }
}
