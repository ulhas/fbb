import { createAnthropic } from '@ai-sdk/anthropic';
import { createOpenAI } from '@ai-sdk/openai';
import type { LanguageModel } from 'ai';

// Mirrors `SharedV3ProviderOptions` from @ai-sdk/provider — it isn't re-
// exported from `ai`, so we restate it locally to keep `generateText`'s
// `providerOptions` argument type-clean.
type ProviderOptions = Record<string, Record<string, JSONValue | undefined>>;
type JSONValue =
  | null
  | string
  | number
  | boolean
  | { [key: string]: JSONValue | undefined }
  | JSONValue[];

import type {
  ModelSpec,
} from '../schemas/parsed-document.schema';

// Catalog of provider + model combinations the day-parser can route to. Each
// entry is what the admin UI shows in the "Reparse with…" picker. Adding a
// model means: add an entry here, ensure the provider's API key is in the
// env, and (for OpenAI reasoning models) confirm the effort levels.
//
// Splitting OpenAI reasoning vs non-reasoning matters because reasoning
// effort is a no-op flag on non-reasoning models — and AI SDK warns when
// you pass `temperature` to a reasoning model. The factory below picks the
// right invocation per family.

export interface ModelCatalogEntry {
  spec: ModelSpec;
  display_name: string;
  // Whether OpenAI's reasoningEffort is meaningful for this model. False for
  // gpt-4o family, claude-*, and any non-reasoning model.
  supports_reasoning_effort: boolean;
  // Whether to set temperature=0. Reasoning models reject this; everyone else
  // benefits from determinism on a structured-output task.
  supports_temperature: boolean;
}

export const DEFAULT_MODEL_SPEC: ModelSpec = {
  provider: 'openai',
  model: 'gpt-5.5-2026-04-23',
  reasoning_effort: 'medium',
};

export const MODEL_CATALOG: ModelCatalogEntry[] = [
  {
    spec: { provider: 'openai', model: 'gpt-5.5-2026-04-23', reasoning_effort: 'medium' },
    display_name: 'OpenAI GPT-5.5 (reasoning)',
    supports_reasoning_effort: true,
    supports_temperature: false,
  },
  {
    spec: { provider: 'openai', model: 'gpt-4o-2024-11-20', reasoning_effort: null },
    display_name: 'OpenAI GPT-4o',
    supports_reasoning_effort: false,
    supports_temperature: true,
  },
  {
    spec: { provider: 'openai', model: 'gpt-4o-mini-2024-07-18', reasoning_effort: null },
    display_name: 'OpenAI GPT-4o mini',
    supports_reasoning_effort: false,
    supports_temperature: true,
  },
  {
    spec: { provider: 'anthropic', model: 'claude-sonnet-4-6', reasoning_effort: null },
    display_name: 'Claude Sonnet 4.6',
    supports_reasoning_effort: false,
    supports_temperature: true,
  },
  {
    spec: { provider: 'anthropic', model: 'claude-haiku-4-5-20251001', reasoning_effort: null },
    display_name: 'Claude Haiku 4.5',
    supports_reasoning_effort: false,
    supports_temperature: true,
  },
];

export function findCatalogEntry(spec: ModelSpec): ModelCatalogEntry | null {
  // Match on provider+model, ignoring reasoning_effort (the picker carries
  // effort separately for OpenAI reasoning models).
  return (
    MODEL_CATALOG.find(
      (e) => e.spec.provider === spec.provider && e.spec.model === spec.model,
    ) ?? null
  );
}

export interface ResolvedModel {
  // Ready-to-pass to ai-sdk's generateText({ model }).
  model: LanguageModel;
  catalog: ModelCatalogEntry;
  providerOptions: ProviderOptions;
  // Whether to send temperature=0 in the generateText call.
  applyTemperatureZero: boolean;
}

export interface ResolveModelInput {
  spec: ModelSpec;
  openaiApiKey: string | undefined;
  anthropicApiKey: string | undefined;
}

// Pure factory — no NestJS dependency, no IO. Throws when the requested
// provider's API key is missing so the day-parser can short-circuit with a
// proper warning.
export function resolveModel(input: ResolveModelInput): ResolvedModel {
  const { spec } = input;
  const catalog = findCatalogEntry(spec);
  if (!catalog) {
    throw new Error(
      `model not in catalog: provider=${spec.provider} model=${spec.model}`,
    );
  }

  if (spec.provider === 'openai') {
    if (!input.openaiApiKey) {
      throw new Error('OPENAI_API_KEY is not configured');
    }
    const openai = createOpenAI({ apiKey: input.openaiApiKey });
    const providerOptions: ProviderOptions = {};
    if (catalog.supports_reasoning_effort && spec.reasoning_effort) {
      providerOptions.openai = { reasoningEffort: spec.reasoning_effort };
    }
    return {
      model: openai(spec.model),
      catalog,
      providerOptions,
      applyTemperatureZero: catalog.supports_temperature,
    };
  }

  if (spec.provider === 'anthropic') {
    if (!input.anthropicApiKey) {
      throw new Error('ANTHROPIC_API_KEY is not configured');
    }
    const anthropic = createAnthropic({ apiKey: input.anthropicApiKey });
    // Force the JSON-output-format path over jsonTool. Anthropic's tool-call
    // mode caps at 16 union-typed parameters, and our day schema has ~50
    // nullable fields — it crashes with "Schemas contains too many parameters
    // with union types" on `auto`. `outputFormat` mode tells the model to
    // emit JSON in the text response; AI SDK then validates with our Zod
    // schema. Same end result, no provider-side schema-shape limit.
    return {
      model: anthropic(spec.model),
      catalog,
      providerOptions: {
        anthropic: { structuredOutputMode: 'outputFormat' },
      },
      applyTemperatureZero: catalog.supports_temperature,
    };
  }

  throw new Error(`unknown provider: ${(spec as { provider: string }).provider}`);
}
