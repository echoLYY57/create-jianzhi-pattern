---
name: create-jianzhi-pattern
description: Convert photographs, illustrations, or text descriptions into recognizable Chinese Jianzhi paper-cut artwork and practical hand-cutting patterns. Use when Codex needs to create red-and-white paper-cut designs, preserve a person, building, animal, or scene from a reference image, generate a paper-cut from a description, choose scissors or knife complexity, enforce connected-paper construction, add culturally appropriate motifs or stencil-safe text, recommend a physical size, or export matching PNG and SVG files.
---

# Create Jianzhi Pattern

Create a visually faithful paper-cut first, then prove that the red paper can be cut and remain usable.

## Workflow

1. Inspect every reference image. Identify the subject, recognizable silhouette, identity cues, pose, composition, text, watermark, and dispensable detail.
2. Ask only for missing choices that materially affect the result. Default to `standard`, front-facing output, scissors-or-knife construction, full original composition, `#D9381E`, and a 250 mm long edge.
3. Read [references/design-rules.md](references/design-rules.md). Read [references/prompt-template.md](references/prompt-template.md) before generating the raster master.
4. Treat an uploaded image as a composition and identity reference. Use the built-in image generation/editing capability to create one strict red-and-white raster master. For a text-only request, infer a clear silhouette and culturally appropriate motifs without inventing unrelated objects.
5. Preserve the principal subject before ornament. Preserve a person's face, hair silhouette, pose, clothing outline, and distinctive accessories through simplified positive and negative shapes. Preserve a building's massing, roofline rhythm, storey count, symmetry, and landmark features before railings or surface decoration.
6. Remove photography, lighting, gradients, shadows, watermarks, signatures, tiny lettering, and accidental texture. Render only solid `#D9381E` and `#FFFFFF`.
7. Enforce the single-sheet rule on red positive space. Try, in order: add discreet bridges; recommend a larger physical size; simplify local patterns; then create a separate `faithful` variant only if strict connectivity materially harms recognition.
8. Run `scripts/process-jianzhi.ps1` on the raster master. Produce the strict red-on-white PNG, matching filled compound-path SVG, and a JSON validation report. Do not claim completion when the report shows more than one red component for a strict variant. Treat a high bridge count as a structural warning: the raster master is too fragmented and should be simplified, enlarged, or regenerated before being called final. Reject visible pixel stair-stepping on major contours; smooth vector outlines are required unless the edge is an intentional local sawtooth motif.
9. Inspect the PNG and SVG visually. Confirm subject recognition, intentional negative space, readable text when requested, no watermark, no frame unless requested, and no unintended red islands.
10. Return the final prompt, physical-size recommendation, output paths, complexity, construction method, strict/faithful status, and any remaining manual-cutting risk.

## Complexity

- Default to `standard` and output only that level.
- Use `simple` for beginners, scissors, small output, or explicit simplification.
- Use `fine` for knife work, larger output, or an explicit intricate request.
- Generate all three only when requested.

## Variants

- Name the normal result `<subject>-standard-strict.png` and `.svg`.
- Add `<subject>-standard-faithful.png` and `.svg` only when important detached red pieces cannot be bridged without obvious visual damage.
- Keep the normal output front-facing. Create a mirrored back-side pattern only when requested.

## Text

Preserve text verbatim only when the user supplies or confirms it. Convert requested text to stencil-safe connected lettering. Add bridges across enclosed counters and connect red lettering to the main paper or a supporting ground. Remove unrequested watermarks, signatures, timestamps, and unreadable source-image lettering.

## Post-process

Run from Windows PowerShell (`powershell.exe`), rather than PowerShell 7 (`pwsh`), because this script uses the Windows `System.Drawing` assembly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\process-jianzhi.ps1" `
  -InputPath "<generated-master.png>" `
  -OutputStem "<output-dir>\<subject>-standard-strict" `
  -Complexity standard `
  -Variant strict `
  -LongEdgeMm 250 `
  -LongEdgePx 3000
```

Use the generated `.report.json` to decide whether to enlarge or simplify. Never substitute a raster image embedded inside SVG; export actual filled vector path geometry with smooth or cleanly straight contours.
