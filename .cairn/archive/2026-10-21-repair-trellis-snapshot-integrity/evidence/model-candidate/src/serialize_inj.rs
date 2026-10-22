//! Verified serialization injectivity for canonical byte encodings.
//!
//! Proves that canonical byte encodings are injective: equal byte
//! sequences imply equal input values. These byte-encoding injectivity
//! theorems concern structure only: they are NOT a SnapshotIntegrity wire
//! codec, and they are not a cryptographic hash/MAC/authentication of
//! payload bytes. Chain hash field equality additionally relies on the
//! chain module's collision-resistance assumption; the SnapshotIntegrity
//! combined commitment is instead exactly injective over its u64 inputs
//! (no collision axiom needed).
//!
//! All encode functions operate at the `Seq<u8>` spec level. Exec
//! wrappers exist for proptest coverage.

use vstd::prelude::*;

verus! {

// ═══════════════════════════════════════════════════════════════════
// u64 little-endian encoding
// ═══════════════════════════════════════════════════════════════════

// r[depends serialize-inj.encode-u64]
/// Spec: encode a u64 as 8 bytes, little-endian.
///
/// Byte i holds bits [8i, 8i+8) of the value.
pub open spec fn encode_u64_spec(v: u64) -> Seq<u8> {
    seq![
        (v & 0xff) as u8,
        ((v >> 8u64) & 0xff) as u8,
        ((v >> 16u64) & 0xff) as u8,
        ((v >> 24u64) & 0xff) as u8,
        ((v >> 32u64) & 0xff) as u8,
        ((v >> 40u64) & 0xff) as u8,
        ((v >> 48u64) & 0xff) as u8,
        ((v >> 56u64) & 0xff) as u8,
    ]
}

// r[depends serialize-inj.decode-u64]
/// Spec: decode a u64 from 8 bytes, little-endian.
pub open spec fn decode_u64_spec(bs: Seq<u8>) -> u64
    recommends bs.len() == 8
{
    (bs[0] as u64)
        | ((bs[1] as u64) << 8u64)
        | ((bs[2] as u64) << 16u64)
        | ((bs[3] as u64) << 24u64)
        | ((bs[4] as u64) << 32u64)
        | ((bs[5] as u64) << 40u64)
        | ((bs[6] as u64) << 48u64)
        | ((bs[7] as u64) << 56u64)
}

// r[impl serialize-inj.encode-u64-length]
// r[verify serialize-inj.encode-u64-length]
/// Proof: encode_u64 always produces exactly 8 bytes.
pub proof fn encode_u64_len(v: u64)
    ensures encode_u64_spec(v).len() == 8
{}

// r[verify serialize-inj.decode-u64]
/// Proof: decode(encode(v)) == v for all u64 values.
proof fn encode_u64_roundtrip(v: u64)
    ensures decode_u64_spec(encode_u64_spec(v)) == v
{
    let bs = encode_u64_spec(v);
    // Extract bytes into locals — by(bit_vector) can't handle Seq::index
    let b0: u8 = bs[0int];
    let b1: u8 = bs[1int];
    let b2: u8 = bs[2int];
    let b3: u8 = bs[3int];
    let b4: u8 = bs[4int];
    let b5: u8 = bs[5int];
    let b6: u8 = bs[6int];
    let b7: u8 = bs[7int];
    assert(
        (b0 as u64)
        | ((b1 as u64) << 8u64)
        | ((b2 as u64) << 16u64)
        | ((b3 as u64) << 24u64)
        | ((b4 as u64) << 32u64)
        | ((b5 as u64) << 40u64)
        | ((b6 as u64) << 48u64)
        | ((b7 as u64) << 56u64)
        == v
    ) by(bit_vector)
        requires
            b0 == (v & 0xff) as u8,
            b1 == ((v >> 8u64) & 0xff) as u8,
            b2 == ((v >> 16u64) & 0xff) as u8,
            b3 == ((v >> 24u64) & 0xff) as u8,
            b4 == ((v >> 32u64) & 0xff) as u8,
            b5 == ((v >> 40u64) & 0xff) as u8,
            b6 == ((v >> 48u64) & 0xff) as u8,
            b7 == ((v >> 56u64) & 0xff) as u8,
    ;
}

// r[verify serialize-inj.encode-u64]
/// Proof: encode_u64 is injective — equal byte sequences imply equal values.
proof fn encode_u64_injective(a: u64, b: u64)
    requires encode_u64_spec(a) == encode_u64_spec(b)
    ensures a == b
{
    encode_u64_roundtrip(a);
    encode_u64_roundtrip(b);
    // decode(encode(a)) == a, decode(encode(b)) == b
    // encode(a) == encode(b) → decode(encode(a)) == decode(encode(b)) → a == b
}

// r[impl serialize-inj.encode-u64]
/// Exec: encode a u64 as 8 bytes, little-endian.
pub fn encode_u64(v: u64) -> (result: Vec<u8>)
    ensures result@ == encode_u64_spec(v)
{
    let b0 = (v & 0xff) as u8;
    let b1 = ((v >> 8u64) & 0xff) as u8;
    let b2 = ((v >> 16u64) & 0xff) as u8;
    let b3 = ((v >> 24u64) & 0xff) as u8;
    let b4 = ((v >> 32u64) & 0xff) as u8;
    let b5 = ((v >> 40u64) & 0xff) as u8;
    let b6 = ((v >> 48u64) & 0xff) as u8;
    let b7 = ((v >> 56u64) & 0xff) as u8;
    let result = vec![b0, b1, b2, b3, b4, b5, b6, b7];
    proof {
        assert(result@ =~= encode_u64_spec(v));
    }
    result
}

// r[impl serialize-inj.decode-u64]
/// Exec: decode a u64 from 8 bytes, little-endian.
pub fn decode_u64(bs: &[u8]) -> (result: u64)
    requires bs@.len() == 8
    ensures result == decode_u64_spec(bs@)
{
    let result =
        (bs[0] as u64)
        | ((bs[1] as u64) << 8u64)
        | ((bs[2] as u64) << 16u64)
        | ((bs[3] as u64) << 24u64)
        | ((bs[4] as u64) << 32u64)
        | ((bs[5] as u64) << 40u64)
        | ((bs[6] as u64) << 48u64)
        | ((bs[7] as u64) << 56u64);
    result
}

// ═══════════════════════════════════════════════════════════════════
// Tag-prefixed encoding
// ═══════════════════════════════════════════════════════════════════

// r[depends serialize-inj.encode-tagged]
/// Spec: prepend a single tag byte to a payload.
pub open spec fn encode_tagged_spec(tag: u8, payload: Seq<u8>) -> Seq<u8> {
    seq![tag] + payload
}

// r[verify serialize-inj.encode-tagged]
/// Proof: encode_tagged produces len(payload) + 1 bytes.
proof fn encode_tagged_len(tag: u8, payload: Seq<u8>)
    ensures encode_tagged_spec(tag, payload).len() == payload.len() + 1
{}

// r[impl serialize-inj.tag-disjoint]
// r[verify serialize-inj.tag-disjoint]
/// Proof: different tags produce different encodings regardless of payload.
proof fn tag_disjoint(t1: u8, t2: u8, p1: Seq<u8>, p2: Seq<u8>)
    requires t1 != t2
    ensures encode_tagged_spec(t1, p1) != encode_tagged_spec(t2, p2)
{
    let e1 = encode_tagged_spec(t1, p1);
    let e2 = encode_tagged_spec(t2, p2);
    // First byte of e1 is t1, first byte of e2 is t2.
    assert(e1[0int] == t1);
    assert(e2[0int] == t2);
    // t1 != t2, so e1 != e2.
}

// r[impl serialize-inj.encode-tagged-injective]
// r[verify serialize-inj.encode-tagged-injective]
/// Proof: same tag with equal encodings implies equal payloads.
proof fn encode_tagged_injective(tag: u8, p1: Seq<u8>, p2: Seq<u8>)
    requires encode_tagged_spec(tag, p1) == encode_tagged_spec(tag, p2)
    ensures p1 == p2
{
    let e1 = encode_tagged_spec(tag, p1);
    let e2 = encode_tagged_spec(tag, p2);
    // e1 == e2, and e1.len() == 1 + p1.len(), e2.len() == 1 + p2.len()
    assert(e1.len() == 1 + p1.len());
    assert(e2.len() == 1 + p2.len());
    // Lengths equal, so p1.len() == p2.len()
    // For each i in 0..p1.len(): e1[1+i] == p1[i] and e2[1+i] == p2[i]
    assert forall|i: int| 0 <= i < p1.len() implies p1[i] == p2[i] by {
        assert(e1[1 + i] == p1[i]);
        assert(e2[1 + i] == p2[i]);
    }
    assert(p1 =~= p2);
}

// r[impl serialize-inj.encode-tagged]
/// Exec: prepend a tag byte to a payload.
pub fn encode_tagged(tag: u8, payload: &[u8]) -> (result: Vec<u8>)
    requires payload@.len() < usize::MAX as int
    ensures result@ == encode_tagged_spec(tag, payload@)
{
    let mut result = Vec::with_capacity(payload.len() + 1);
    result.push(tag);
    let mut i: usize = 0;
    while i < payload.len()
        invariant
            0 <= i <= payload.len(),
            result@.len() == 1 + i as int,
            result@[0int] == tag,
            forall|j: int| 0 <= j < i as int ==> result@[j + 1] == payload@[j],
        decreases payload.len() - i
    {
        result.push(payload[i]);
        i = i + 1;
    }
    proof {
        assert(result@ =~= encode_tagged_spec(tag, payload@));
    }
    result
}

// ═══════════════════════════════════════════════════════════════════
// Length-prefixed encoding
// ═══════════════════════════════════════════════════════════════════

// r[depends serialize-inj.encode-len-prefixed]
/// Spec: encode data with an 8-byte LE length prefix.
pub open spec fn encode_len_prefixed_spec(data: Seq<u8>) -> Seq<u8>
    recommends data.len() <= u64::MAX as int
{
    encode_u64_spec(data.len() as u64) + data
}

// r[verify serialize-inj.encode-len-prefixed]
/// Proof: length-prefixed encoding is injective.
proof fn encode_len_prefixed_injective(a: Seq<u8>, b: Seq<u8>)
    requires
        a.len() <= u64::MAX as int,
        b.len() <= u64::MAX as int,
        encode_len_prefixed_spec(a) == encode_len_prefixed_spec(b),
    ensures a == b
{
    let ea = encode_len_prefixed_spec(a);
    let eb = encode_len_prefixed_spec(b);
    // ea == eb means encode_u64(a.len()) + a == encode_u64(b.len()) + b.
    // First 8 bytes: encode_u64(a.len()) == encode_u64(b.len()).
    let la = encode_u64_spec(a.len() as u64);
    let lb = encode_u64_spec(b.len() as u64);
    assert(la.len() == 8) by { encode_u64_len(a.len() as u64); }
    assert(lb.len() == 8) by { encode_u64_len(b.len() as u64); }
    // First 8 bytes are equal.
    assert(la =~= ea.subrange(0, 8));
    assert(lb =~= eb.subrange(0, 8));
    assert(la =~= lb);
    // Therefore a.len() == b.len().
    encode_u64_injective(a.len() as u64, b.len() as u64);
    // Remaining bytes: a == b.
    assert(a =~= ea.subrange(8, ea.len() as int));
    assert(b =~= eb.subrange(8, eb.len() as int));
    assert(a =~= b);
}

// r[verify serialize-inj.encode-len-prefixed]
/// Proof: the first 8 bytes of a length-prefixed encoding decode to data.len().
proof fn encode_len_prefixed_length_recovery(data: Seq<u8>)
    requires data.len() <= u64::MAX as int
    ensures decode_u64_spec(encode_len_prefixed_spec(data).subrange(0, 8)) == data.len() as u64
{
    let encoded = encode_len_prefixed_spec(data);
    let la = encode_u64_spec(data.len() as u64);
    encode_u64_len(data.len() as u64);
    assert(la =~= encoded.subrange(0, 8));
    encode_u64_roundtrip(data.len() as u64);
}

// r[impl serialize-inj.encode-len-prefixed]
/// Exec: encode data with a length prefix.
pub fn encode_len_prefixed(data: &[u8]) -> (result: Vec<u8>)
    requires data@.len() <= usize::MAX as int - 8
    ensures result@ == encode_len_prefixed_spec(data@)
{
    let len_bytes = encode_u64(data.len() as u64);
    let mut result = Vec::with_capacity(8 + data.len());
    let mut i: usize = 0;
    while i < 8
        invariant
            0 <= i <= 8,
            len_bytes@.len() == 8,
            result@.len() == i as int,
            forall|j: int| 0 <= j < i as int ==> result@[j] == len_bytes@[j],
        decreases 8 - i
    {
        result.push(len_bytes[i]);
        i = i + 1;
    }
    let mut k: usize = 0;
    while k < data.len()
        invariant
            0 <= k <= data.len(),
            data@.len() <= usize::MAX as int - 8,
            result@.len() == 8 + k as int,
            forall|j: int| 0 <= j < 8 ==> result@[j] == len_bytes@[j],
            forall|j: int| 0 <= j < k as int ==> result@[8 + j] == data@[j],
        decreases data.len() - k
    {
        result.push(data[k]);
        k = k + 1;
    }
    proof {
        assert(result@ =~= encode_len_prefixed_spec(data@));
    }
    result
}

// ═══════════════════════════════════════════════════════════════════
// Pair encoding (two u64 fields)
// ═══════════════════════════════════════════════════════════════════

// r[depends serialize-inj.encode-pair]
/// Spec: concatenate two u64 LE encodings into 16 bytes.
pub open spec fn encode_pair_spec(a: u64, b: u64) -> Seq<u8> {
    encode_u64_spec(a) + encode_u64_spec(b)
}

// r[verify serialize-inj.encode-pair]
/// Proof: encode_pair output is exactly 16 bytes.
proof fn encode_pair_len(a: u64, b: u64)
    ensures encode_pair_spec(a, b).len() == 16
{
    encode_u64_len(a);
    encode_u64_len(b);
}

// r[verify serialize-inj.encode-pair]
/// Proof: pair encoding is injective.
proof fn encode_pair_injective(a1: u64, b1: u64, a2: u64, b2: u64)
    requires encode_pair_spec(a1, b1) == encode_pair_spec(a2, b2)
    ensures a1 == a2 && b1 == b2
{
    let e1 = encode_pair_spec(a1, b1);
    let e2 = encode_pair_spec(a2, b2);
    let ea1 = encode_u64_spec(a1);
    let ea2 = encode_u64_spec(a2);
    let eb1 = encode_u64_spec(b1);
    let eb2 = encode_u64_spec(b2);
    // Both encodings are 8 bytes.
    encode_u64_len(a1);
    encode_u64_len(a2);
    encode_u64_len(b1);
    encode_u64_len(b2);
    // First 8 bytes: ea1 == ea2.
    assert(ea1 =~= e1.subrange(0, 8));
    assert(ea2 =~= e2.subrange(0, 8));
    assert(ea1 =~= ea2);
    encode_u64_injective(a1, a2);
    // Last 8 bytes: eb1 == eb2.
    assert(eb1 =~= e1.subrange(8, 16));
    assert(eb2 =~= e2.subrange(8, 16));
    assert(eb1 =~= eb2);
    encode_u64_injective(b1, b2);
}

// r[impl serialize-inj.encode-pair]
/// Exec: encode a pair of u64 values.
pub fn encode_pair(a: u64, b: u64) -> (result: Vec<u8>)
    ensures result@ == encode_pair_spec(a, b)
{
    let ea = encode_u64(a);
    let eb = encode_u64(b);
    let mut result = Vec::with_capacity(16);
    let mut i: usize = 0;
    while i < 8
        invariant
            0 <= i <= 8,
            ea@.len() == 8,
            result@.len() == i as int,
            forall|j: int| 0 <= j < i as int ==> result@[j] == ea@[j],
        decreases 8 - i
    {
        result.push(ea[i]);
        i = i + 1;
    }
    let mut k: usize = 0;
    while k < 8
        invariant
            0 <= k <= 8,
            ea@.len() == 8,
            eb@.len() == 8,
            result@.len() == 8 + k as int,
            forall|j: int| 0 <= j < 8 ==> result@[j] == ea@[j],
            forall|j: int| 0 <= j < k as int ==> result@[8 + j] == eb@[j],
        decreases 8 - k
    {
        result.push(eb[k]);
        k = k + 1;
    }
    proof {
        assert(result@ =~= encode_pair_spec(a, b));
    }
    result
}

// ═══════════════════════════════════════════════════════════════════
// Quad encoding (four u64 fields)
// ═══════════════════════════════════════════════════════════════════

// r[depends serialize-inj.encode-quad]
/// Spec: concatenate four u64 LE encodings into 32 bytes.
pub open spec fn encode_quad_spec(a: u64, b: u64, c: u64, d: u64) -> Seq<u8> {
    encode_u64_spec(a) + encode_u64_spec(b) + encode_u64_spec(c) + encode_u64_spec(d)
}

// r[verify serialize-inj.encode-quad]
/// Proof: encode_quad output is exactly 32 bytes.
proof fn encode_quad_len(a: u64, b: u64, c: u64, d: u64)
    ensures encode_quad_spec(a, b, c, d).len() == 32
{
    encode_u64_len(a);
    encode_u64_len(b);
    encode_u64_len(c);
    encode_u64_len(d);
}

// r[verify serialize-inj.encode-quad]
/// Proof: quad encoding is injective.
proof fn encode_quad_injective(
    a1: u64, b1: u64, c1: u64, d1: u64,
    a2: u64, b2: u64, c2: u64, d2: u64,
)
    requires encode_quad_spec(a1, b1, c1, d1) == encode_quad_spec(a2, b2, c2, d2)
    ensures a1 == a2 && b1 == b2 && c1 == c2 && d1 == d2
{
    let e1 = encode_quad_spec(a1, b1, c1, d1);
    let e2 = encode_quad_spec(a2, b2, c2, d2);
    let ea1 = encode_u64_spec(a1);
    let ea2 = encode_u64_spec(a2);
    let eb1 = encode_u64_spec(b1);
    let eb2 = encode_u64_spec(b2);
    let ec1 = encode_u64_spec(c1);
    let ec2 = encode_u64_spec(c2);
    let ed1 = encode_u64_spec(d1);
    let ed2 = encode_u64_spec(d2);

    encode_u64_len(a1);
    encode_u64_len(a2);
    encode_u64_len(b1);
    encode_u64_len(b2);
    encode_u64_len(c1);
    encode_u64_len(c2);
    encode_u64_len(d1);
    encode_u64_len(d2);

    // Field a: bytes [0, 8)
    assert(ea1 =~= e1.subrange(0, 8));
    assert(ea2 =~= e2.subrange(0, 8));
    assert(ea1 =~= ea2);
    encode_u64_injective(a1, a2);

    // Field b: bytes [8, 16)
    assert(eb1 =~= e1.subrange(8, 16));
    assert(eb2 =~= e2.subrange(8, 16));
    assert(eb1 =~= eb2);
    encode_u64_injective(b1, b2);

    // Field c: bytes [16, 24)
    assert(ec1 =~= e1.subrange(16, 24));
    assert(ec2 =~= e2.subrange(16, 24));
    assert(ec1 =~= ec2);
    encode_u64_injective(c1, c2);

    // Field d: bytes [24, 32)
    assert(ed1 =~= e1.subrange(24, 32));
    assert(ed2 =~= e2.subrange(24, 32));
    assert(ed1 =~= ed2);
    encode_u64_injective(d1, d2);
}

// r[impl serialize-inj.encode-quad]
/// Exec: encode four u64 values.
pub fn encode_quad(a: u64, b: u64, c: u64, d: u64) -> (result: Vec<u8>)
    ensures result@ == encode_quad_spec(a, b, c, d)
{
    let ea = encode_u64(a);
    let eb = encode_u64(b);
    let ec = encode_u64(c);
    let ed = encode_u64(d);
    let mut result = Vec::with_capacity(32);
    // Copy all four 8-byte segments
    let mut i: usize = 0;
    while i < 8
        invariant
            0 <= i <= 8,
            ea@.len() == 8,
            result@.len() == i as int,
            forall|j: int| 0 <= j < i as int ==> result@[j] == ea@[j],
        decreases 8 - i
    {
        result.push(ea[i]);
        i = i + 1;
    }
    i = 0;
    while i < 8
        invariant
            0 <= i <= 8,
            ea@.len() == 8,
            eb@.len() == 8,
            result@.len() == 8 + i as int,
            forall|j: int| 0 <= j < 8 ==> result@[j] == ea@[j],
            forall|j: int| 0 <= j < i as int ==> result@[8 + j] == eb@[j],
        decreases 8 - i
    {
        result.push(eb[i]);
        i = i + 1;
    }
    i = 0;
    while i < 8
        invariant
            0 <= i <= 8,
            ea@.len() == 8,
            eb@.len() == 8,
            ec@.len() == 8,
            result@.len() == 16 + i as int,
            forall|j: int| 0 <= j < 8 ==> result@[j] == ea@[j],
            forall|j: int| 0 <= j < 8 ==> result@[8 + j] == eb@[j],
            forall|j: int| 0 <= j < i as int ==> result@[16 + j] == ec@[j],
        decreases 8 - i
    {
        result.push(ec[i]);
        i = i + 1;
    }
    i = 0;
    while i < 8
        invariant
            0 <= i <= 8,
            ea@.len() == 8,
            eb@.len() == 8,
            ec@.len() == 8,
            ed@.len() == 8,
            result@.len() == 24 + i as int,
            forall|j: int| 0 <= j < 8 ==> result@[j] == ea@[j],
            forall|j: int| 0 <= j < 8 ==> result@[8 + j] == eb@[j],
            forall|j: int| 0 <= j < 8 ==> result@[16 + j] == ec@[j],
            forall|j: int| 0 <= j < i as int ==> result@[24 + j] == ed@[j],
        decreases 8 - i
    {
        result.push(ed[i]);
        i = i + 1;
    }
    proof {
        assert(result@ =~= encode_quad_spec(a, b, c, d));
    }
    result
}

// ═══════════════════════════════════════════════════════════════════
// Cross-module composition
// ═══════════════════════════════════════════════════════════════════

// r[depends serialize-inj.chain-hash-compose]
/// Spec: chain hash structural injectivity property.
///
/// Equal chain hashes imply equal (prev, index, term, data_id) fields.
/// This follows from encode_quad_injective + hash_collision_free.
pub open spec fn chain_hash_struct_injective_prop(
    prev1: u64, idx1: u64, term1: u64, data1: u64,
    prev2: u64, idx2: u64, term2: u64, data2: u64,
) -> bool {
    (encode_quad_spec(prev1, idx1, term1, data1) == encode_quad_spec(prev2, idx2, term2, data2))
        ==> (prev1 == prev2 && idx1 == idx2 && term1 == term2 && data1 == data2)
}

// r[impl serialize-inj.chain-hash-compose]
// r[verify serialize-inj.chain-hash-compose]
/// Proof: chain hash fields are structurally injective via quad encoding.
proof fn chain_hash_struct_injective(
    prev1: u64, idx1: u64, term1: u64, data1: u64,
    prev2: u64, idx2: u64, term2: u64, data2: u64,
)
    requires encode_quad_spec(prev1, idx1, term1, data1) == encode_quad_spec(prev2, idx2, term2, data2)
    ensures prev1 == prev2 && idx1 == idx2 && term1 == term2 && data1 == data2
{
    encode_quad_injective(prev1, idx1, term1, data1, prev2, idx2, term2, data2);
}

// r[depends serialize-inj.dual-hash-compose]
/// Spec: dual hash structural injectivity property.
///
/// Equal dual hash encodings imply equal (a, b) fields.
pub open spec fn dual_hash_struct_injective_prop(
    a1: u64, b1: u64,
    a2: u64, b2: u64,
) -> bool {
    (encode_pair_spec(a1, b1) == encode_pair_spec(a2, b2))
        ==> (a1 == a2 && b1 == b2)
}

// r[impl serialize-inj.dual-hash-compose]
// r[verify serialize-inj.dual-hash-compose]
/// Proof: dual hash fields are structurally injective via pair encoding.
proof fn dual_hash_struct_injective(
    a1: u64, b1: u64,
    a2: u64, b2: u64,
)
    requires encode_pair_spec(a1, b1) == encode_pair_spec(a2, b2)
    ensures a1 == a2 && b1 == b2
{
    encode_pair_injective(a1, b1, a2, b2);
}

} // verus!

#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    use super::*;

    // r[verify serialize-inj.encode-u64]
    #[test]
    fn test_encode_u64_zero() {
        let bs = encode_u64(0);
        assert_eq!(bs.len(), 8);
        assert_eq!(bs, vec![0, 0, 0, 0, 0, 0, 0, 0]);
    }

    // r[verify serialize-inj.encode-u64]
    #[test]
    fn test_encode_u64_one() {
        let bs = encode_u64(1);
        assert_eq!(bs.len(), 8);
        assert_eq!(bs[0], 1);
        for i in 1..8 {
            assert_eq!(bs[i], 0);
        }
    }

    // r[verify serialize-inj.encode-u64]
    #[test]
    fn test_encode_u64_max() {
        let bs = encode_u64(u64::MAX);
        assert_eq!(bs.len(), 8);
        for i in 0..8 {
            assert_eq!(bs[i], 0xff);
        }
    }

    // r[verify serialize-inj.decode-u64]
    #[test]
    fn test_decode_u64_roundtrip() {
        for v in [0u64, 1, 255, 256, 0xDEAD_BEEF, u64::MAX] {
            let encoded = encode_u64(v);
            let decoded = decode_u64(&encoded);
            assert_eq!(decoded, v);
        }
    }

    // r[verify serialize-inj.encode-tagged]
    #[test]
    fn test_encode_tagged_basic() {
        let result = encode_tagged(0x42, &[1, 2, 3]);
        assert_eq!(result, vec![0x42, 1, 2, 3]);
    }

    // r[verify serialize-inj.tag-disjoint]
    #[test]
    fn test_tag_disjoint() {
        let e1 = encode_tagged(0x10, &[1, 2, 3]);
        let e2 = encode_tagged(0x20, &[1, 2, 3]);
        assert_ne!(e1, e2);
    }

    // r[verify serialize-inj.encode-len-prefixed]
    #[test]
    fn test_encode_len_prefixed_empty() {
        let result = encode_len_prefixed(&[]);
        assert_eq!(result.len(), 8);
        // Length header decodes to 0.
        assert_eq!(decode_u64(&result[..8]), 0);
    }

    // r[verify serialize-inj.encode-len-prefixed]
    #[test]
    fn test_encode_len_prefixed_data() {
        let data = [10u8, 20, 30];
        let result = encode_len_prefixed(&data);
        assert_eq!(result.len(), 11);
        assert_eq!(decode_u64(&result[..8]), 3);
        assert_eq!(&result[8..], &data);
    }

    // r[verify serialize-inj.encode-pair]
    #[test]
    fn test_encode_pair_roundtrip() {
        let encoded = encode_pair(42, 99);
        assert_eq!(encoded.len(), 16);
        assert_eq!(decode_u64(&encoded[..8]), 42);
        assert_eq!(decode_u64(&encoded[8..16]), 99);
    }

    // r[verify serialize-inj.encode-quad]
    #[test]
    fn test_encode_quad_roundtrip() {
        let encoded = encode_quad(1, 2, 3, 4);
        assert_eq!(encoded.len(), 32);
        assert_eq!(decode_u64(&encoded[..8]), 1);
        assert_eq!(decode_u64(&encoded[8..16]), 2);
        assert_eq!(decode_u64(&encoded[16..24]), 3);
        assert_eq!(decode_u64(&encoded[24..32]), 4);
    }

    proptest! {
        // r[verify serialize-inj.decode-u64]
        #[test]
        fn prop_u64_roundtrip(v: u64) {
            let encoded = encode_u64(v);
            prop_assert_eq!(encoded.len(), 8);
            let decoded = decode_u64(&encoded);
            prop_assert_eq!(decoded, v);
        }

        // r[verify serialize-inj.encode-u64]
        #[test]
        fn prop_u64_injective(a: u64, b: u64) {
            let ea = encode_u64(a);
            let eb = encode_u64(b);
            if ea == eb {
                prop_assert_eq!(a, b);
            }
        }

        // r[verify serialize-inj.tag-disjoint]
        #[test]
        fn prop_tag_disjoint(t1: u8, t2: u8, p1 in proptest::collection::vec(any::<u8>(), 0..32), p2 in proptest::collection::vec(any::<u8>(), 0..32)) {
            if t1 != t2 {
                let e1 = encode_tagged(t1, &p1);
                let e2 = encode_tagged(t2, &p2);
                prop_assert_ne!(e1, e2);
            }
        }

        // r[verify serialize-inj.encode-tagged-injective]
        #[test]
        fn prop_tagged_same_tag_injective(tag: u8, p1 in proptest::collection::vec(any::<u8>(), 0..32), p2 in proptest::collection::vec(any::<u8>(), 0..32)) {
            let e1 = encode_tagged(tag, &p1);
            let e2 = encode_tagged(tag, &p2);
            if e1 == e2 {
                prop_assert_eq!(p1, p2);
            }
        }

        // r[verify serialize-inj.encode-len-prefixed]
        #[test]
        fn prop_len_prefixed_injective(a in proptest::collection::vec(any::<u8>(), 0..64), b in proptest::collection::vec(any::<u8>(), 0..64)) {
            let ea = encode_len_prefixed(&a);
            let eb = encode_len_prefixed(&b);
            if ea == eb {
                prop_assert_eq!(a, b);
            }
        }

        // r[verify serialize-inj.encode-pair]
        #[test]
        fn prop_pair_injective(a1: u64, b1: u64, a2: u64, b2: u64) {
            let e1 = encode_pair(a1, b1);
            let e2 = encode_pair(a2, b2);
            if e1 == e2 {
                prop_assert_eq!(a1, a2);
                prop_assert_eq!(b1, b2);
            }
        }

        // r[verify serialize-inj.encode-quad]
        #[test]
        fn prop_quad_injective(a1: u64, b1: u64, c1: u64, d1: u64) {
            let e1 = encode_quad(a1, b1, c1, d1);
            // Decode and re-encode to check roundtrip
            let a2 = decode_u64(&e1[..8]);
            let b2 = decode_u64(&e1[8..16]);
            let c2 = decode_u64(&e1[16..24]);
            let d2 = decode_u64(&e1[24..32]);
            prop_assert_eq!(a1, a2);
            prop_assert_eq!(b1, b2);
            prop_assert_eq!(c1, c2);
            prop_assert_eq!(d1, d2);
        }

        // r[verify serialize-inj.encode-quad]
        #[test]
        fn prop_quad_encoding_injective(
            a1: u64, b1: u64, c1: u64, d1: u64,
            a2: u64, b2: u64, c2: u64, d2: u64,
        ) {
            let e1 = encode_quad(a1, b1, c1, d1);
            let e2 = encode_quad(a2, b2, c2, d2);
            if e1 == e2 {
                prop_assert_eq!(a1, a2);
                prop_assert_eq!(b1, b2);
                prop_assert_eq!(c1, c2);
                prop_assert_eq!(d1, d2);
            }
        }

        // r[verify serialize-inj.encode-pair]
        #[test]
        fn prop_pair_length(a: u64, b: u64) {
            let encoded = encode_pair(a, b);
            prop_assert_eq!(encoded.len(), 16);
        }

        // r[verify serialize-inj.encode-quad]
        #[test]
        fn prop_quad_length(a: u64, b: u64, c: u64, d: u64) {
            let encoded = encode_quad(a, b, c, d);
            prop_assert_eq!(encoded.len(), 32);
        }
    }
}
