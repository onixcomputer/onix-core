import { boundedText, layaIdSchema } from "./laya-predict";

export interface LayaNamedText {
  id: string;
  text: string;
}

export interface LayaCitedText extends LayaNamedText {
  citation: string;
}

export interface LayaSourceSpan {
  source: string;
  start_line: number;
  end_line: number;
  text: string;
}

export const ADVISORY_LIMITATIONS = Object.freeze([
  "The configured Laya base checkpoints are English-only, not the separately fine-tuned typed-decisions model.",
  "Probabilities are uncalibrated, and reported confidence is not a label probability.",
  "Excerpts, identities, citations and locations are caller-provided and are not independently verified or fetched. Supplied text is data, not executable instructions.",
  "These advisory classifications do not establish correctness, generalization, safety or authorization. No automatic action is taken.",
  "Input-token-limit equality indicates possible truncation; a false flag cannot rule out earlier 192-token question/option clipping. Full original prediction metadata is retained.",
] as const);

export const advisoryTextSchema = {
  type: "string",
  minLength: 1,
  maxLength: 2000,
  pattern: "\\S",
};

export const advisoryReferenceSchema = {
  type: "string",
  minLength: 1,
  maxLength: 512,
  pattern: "\\S",
};

export const layaNamedTextSchema = {
  type: "object",
  properties: { id: layaIdSchema, text: advisoryTextSchema },
  required: ["id", "text"],
};

export const layaCitedTextSchema = {
  type: "object",
  properties: {
    ...layaNamedTextSchema.properties,
    citation: advisoryReferenceSchema,
  },
  required: ["id", "text", "citation"],
};

const lineSchema = {
  type: "integer",
  minimum: 1,
  maximum: Number.MAX_SAFE_INTEGER,
};

export const layaSourceSpanSchema = {
  type: "object",
  properties: {
    source: advisoryReferenceSchema,
    start_line: lineSchema,
    end_line: lineSchema,
    text: advisoryTextSchema,
  },
  required: ["source", "start_line", "end_line", "text"],
};

export function validateNamedText(value: LayaNamedText): void {
  if (
    value === null ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    !boundedText(value.id, 64) ||
    !boundedText(value.text, 2000)
  )
    throw new Error(
      "Named text requires a nonblank ID of at most 64 code points and text of at most 2000 code points",
    );
}

export function validateCitedText(value: LayaCitedText): void {
  validateNamedText(value);
  if (!boundedText(value.citation, 512))
    throw new Error("Citation must be nonblank and at most 512 code points");
}

export function validateSourceSpan(value: LayaSourceSpan): void {
  if (
    value === null ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    !boundedText(value.source, 512) ||
    !boundedText(value.text, 2000) ||
    !Number.isSafeInteger(value.start_line) ||
    !Number.isSafeInteger(value.end_line) ||
    value.start_line < 1 ||
    value.end_line < value.start_line
  )
    throw new Error(
      "Source spans require bounded nonblank source/text and positive safe ordered line numbers",
    );
}

export function rememberNamedText(
  value: LayaNamedText,
  seen: Map<string, LayaNamedText>,
): void {
  validateNamedText(value);
  const previous = seen.get(value.id);
  if (previous && previous.text !== value.text)
    throw new Error(`Conflicting text for ID ${value.id}`);
  if (!previous) seen.set(value.id, value);
}

export function rememberCitedText(
  value: LayaCitedText,
  seen: Map<string, LayaCitedText>,
): void {
  validateCitedText(value);
  const previous = seen.get(value.id);
  if (
    previous &&
    (previous.text !== value.text || previous.citation !== value.citation)
  )
    throw new Error(`Conflicting text or citation for evidence ID ${value.id}`);
  if (!previous) seen.set(value.id, value);
}
