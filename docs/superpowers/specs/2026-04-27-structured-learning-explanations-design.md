# Structured Learning Explanations Design

## Purpose

Vocra will replace free-form Markdown explanations with structured learning documents rendered by native SwiftUI components. The goal is to make sentence analysis, word explanation, and vocabulary cards visually consistent over time, even when the configured AI model or prompt changes.

The target experience is a deep-learning view: rich, sectioned, and diagram-like. It should support studying a sentence or vocabulary item carefully rather than only giving a short reading aid.

## Decisions

- Use structured JSON from the AI instead of Markdown.
- Use app-owned SwiftUI components for all visual style, layout, colors, headings, icons, and section order.
- Apply the same structured pipeline to sentence analysis, word explanation, and vocabulary cards.
- Keep two prompt layers:
  - Normal users configure learning preferences such as explanation depth and example count.
  - Advanced users may edit schema prompts, but the app still validates responses against the same data contract.
- Do not migrate old Markdown vocabulary data. The app will switch to the new structured format.

## Non-Goals

- No Markdown rendering for new AI explanations.
- No automatic migration from `cardMarkdown` to structured data.
- No model-controlled CSS, HTML, SVG, Mermaid, or arbitrary layout instructions.
- No full local grammar parser in the first implementation.
- No social sharing, export, or image-generation workflow.

## Product Model

The feature is a learning card system with three modes:

- `sentence`: sentence analysis with structure, clause relationships, translation, logic summary, and key vocabulary.
- `word`: word explanation with core meaning, contextual meaning, usage, collocations, examples, and common mistakes.
- `vocabularyCard`: review-oriented card content with front, back, examples, hints, and memory notes.

Each mode is represented by one `LearningExplanationDocument` root object:

```json
{
  "schemaVersion": 1,
  "mode": "sentence",
  "sourceText": "Codex works best when you treat it less like a one-off assistant and more like a teammate you configure and improve over time.",
  "language": {
    "source": "en",
    "explanation": "zh-Hans"
  },
  "sentenceAnalysis": {},
  "wordExplanation": null,
  "vocabularyCard": null,
  "warnings": []
}
```

This root example is abbreviated. Only the branch matching `mode` is populated with a complete payload. Other branches are `null`.

## Sentence Analysis Schema

Sentence analysis should provide enough structure for a diagram-like study view:

```json
{
  "headline": {
    "title": "例句解析",
    "subtitle": "Sentence Analysis"
  },
  "sentence": {
    "text": "Codex works best when you treat it less like a one-off assistant and more like a teammate you configure and improve over time.",
    "segments": [
      {
        "id": "main-subject",
        "text": "Codex",
        "role": "subject",
        "labelZh": "主语",
        "labelEn": "Subject",
        "color": "blue"
      }
    ]
  },
  "structureBreakdown": {
    "title": "从句结构解析",
    "items": [
      {
        "id": "when-clause",
        "text": "when you treat it less like a one-off assistant and more like a teammate you configure and improve over time",
        "role": "adverbialClause",
        "labelZh": "when 引导的状语从句",
        "labelEn": "Adverbial Clause",
        "children": []
      }
    ]
  },
  "relationshipDiagram": {
    "nodes": [
      {
        "id": "main",
        "title": "主句（主干）",
        "text": "Codex works best"
      },
      {
        "id": "condition",
        "title": "when 引导的状语从句",
        "text": "you treat it..."
      }
    ],
    "edges": [
      {
        "from": "condition",
        "to": "main",
        "labelZh": "在这种情境下",
        "labelEn": "condition / time"
      }
    ]
  },
  "logicSummary": {
    "title": "句子逻辑与核心含义",
    "points": [
      "Codex works best 是主干。",
      "when you treat it... 说明效果最好的条件或情境。"
    ],
    "coreMeaning": "把 Codex 当作可长期配置和持续优化的队友时，效果最好。"
  },
  "translation": {
    "title": "例句翻译",
    "text": "当你不把 Codex 当成一次性助手，而是把它当成一个可以长期配置并不断优化的队友时，它的效果最好。"
  },
  "keyVocabulary": [
    {
      "term": "one-off",
      "meaning": "一次性的；仅此一次的",
      "note": "强调不是长期关系。"
    }
  ]
}
```

The schema captures content and relationships only. Visual details are limited to semantic color tokens such as `blue`, `green`, `orange`, `purple`, `pink`, and `neutral`; actual colors are owned by SwiftUI.

## Word Explanation Schema

Word explanations use the same document root with a `wordExplanation` branch:

```json
{
  "term": "configure",
  "pronunciation": "/kənˈfɪɡjər/",
  "partOfSpeech": "verb",
  "coreMeaning": "配置；设定",
  "contextualMeaning": "根据需求进行设置和调整",
  "usageNotes": [
    "常用于软件、系统、工具或参数。"
  ],
  "collocations": [
    "configure settings",
    "configure a tool",
    "configure the environment"
  ],
  "examples": [
    {
      "sentence": "You can configure the tool for your workflow.",
      "translation": "你可以根据自己的工作流配置这个工具。",
      "note": "强调按个人需求调整。"
    }
  ],
  "commonMistakes": [
    "不要把 configure 简单理解成 install；它更强调设置参数。"
  ]
}
```

## Vocabulary Card Schema

Vocabulary cards are review data, not display Markdown:

```json
{
  "front": {
    "text": "configure",
    "hint": "software settings"
  },
  "back": {
    "coreMeaning": "配置；设定",
    "memoryNote": "con- + figure，可以理解为把系统形态设置好。",
    "usage": "常用于配置工具、系统、环境、选项。"
  },
  "examples": [
    {
      "sentence": "Configure the app before your first use.",
      "translation": "首次使用前先配置这个应用。"
    }
  ],
  "reviewPrompts": [
    "What does configure emphasize: installing or setting options?"
  ]
}
```

Scheduling metadata remains app-owned. The AI never controls `nextReviewAt`, `reviewCount`, status, or familiarity level.

## AI Output Contract

The AI client should request JSON only:

- The prompt includes the exact schema and a small valid example.
- The response must be a single JSON object, with no Markdown fences or surrounding prose.
- The prompt names required and optional fields.
- Advanced schema prompt editing is available in settings, but the app still validates the decoded result.

Recommended normal-user controls:

- Explanation depth: `standard`, `detailed`.
- Example count: `1`, `2`, `3`.
- Chinese explanation style: `concise`, `teacherLike`.
- Diagram density: `simple`, `full`.

These controls compile into the schema prompt. They do not change the SwiftUI component contract.

## Validation and Recovery

Vocra validates AI output before showing it:

- JSON must decode into `LearningExplanationDocument`.
- `schemaVersion` must be supported.
- `mode` must match the requested explanation mode.
- `sourceText` must match the captured text after trimming and whitespace normalization.
- Required display sections must be present for the active mode.
- Segment, node, and edge IDs must be unique within their local section.
- Unknown semantic color tokens fall back to `neutral`.
- Long fields are truncated for layout safety.

If validation fails, Vocra retries once with a repair prompt that includes the validation errors and asks for the same JSON object again. If repair fails, the panel shows a structured error state with the raw validation summary and a regenerate action. It should not render raw untrusted Markdown as a fallback.

## Rendering Architecture

New rendering flow:

```text
CapturedText
→ PromptRenderer
→ OpenAI-compatible API
→ raw JSON string
→ LearningExplanationDecoder
→ LearningExplanationDocument
→ ExplanationPanelView
→ mode-specific SwiftUI learning views
```

The panel body switches on `document.mode`:

- `SentenceLearningView`
- `WordLearningView`
- `VocabularyCardLearningView`

Shared components:

- `LearningHeaderView`
- `SentenceSegmentRibbon`
- `GrammarBadge`
- `RelationshipDiagramView`
- `LearningSection`
- `TranslationBlock`
- `VocabularyTermCard`
- `ReviewCardBackView`

The SwiftUI components own all display decisions: typography, spacing, colors, borders, icons, section order, and responsive wrapping.

## Database Changes

Current vocabulary storage uses `cardMarkdown`. The new design replaces this with structured card JSON. This is a breaking local storage change.

Proposed stored fields:

- `id`
- `text`
- `type`
- `cardJSON`
- `schemaVersion`
- `sourceApp`
- `createdAt`
- `updatedAt`
- `lastReviewedAt`
- `nextReviewAt`
- `reviewCount`
- `status`
- `familiarityLevel`

Because old data does not need migration, implementation should reset the local vocabulary storage to the structured schema during the breaking upgrade. The app starts with an empty structured vocabulary table after the upgrade.

## Settings

Settings should expose two tiers:

- Basic learning settings for normal use.
- Advanced schema prompts for users who want full control.

The advanced editor should clearly state that changing the prompt cannot change the output schema. Invalid output will be rejected and may require restoring defaults.

Prompt slots become:

- Sentence analysis schema prompt.
- Word explanation schema prompt.
- Vocabulary card schema prompt.

The old Markdown prompt slots are replaced by these schema prompt slots.

## Error Handling

Panel states:

- Loading after text capture.
- Valid structured explanation.
- Validation error with regenerate.
- API error.
- Unsupported schema version.

Copy behavior:

- For normal copy, copy a readable plain-text summary generated locally from the structured document.
- For advanced/debug copy, copy the validated JSON document.

## Testing Strategy

Unit tests:

- Decode valid sentence, word, and vocabulary JSON.
- Reject malformed JSON.
- Reject mode mismatch.
- Reject missing required sections.
- Normalize and compare source text.
- Validate unique IDs.
- Convert structured documents into plain-text copy summaries.
- Store and reload `cardJSON`.

View tests:

- Ensure sentence, word, and vocabulary modes route to the correct SwiftUI view.
- Ensure validation errors show an error state instead of raw model output.

Manual checks:

- Generate a sentence analysis for a long sentence.
- Generate a word explanation.
- Generate a vocabulary card and review it.
- Try an intentionally broken advanced schema prompt and verify repair/error behavior.

## Implementation Notes

This design intentionally keeps local grammar parsing out of the first implementation. The schema should leave room for a later local parser by keeping sentence segments, relationships, and roles as app-level concepts instead of model-specific prose.

The first implementation can use the AI to infer grammar structure, then let validation and fixed rendering maintain UI consistency.
