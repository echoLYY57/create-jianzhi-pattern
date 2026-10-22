# Jianzhi design rules

## Construction priorities

1. Recognizable outer silhouette and composition.
2. One connected red sheet for a strict variant.
3. Stable bridges and cuttable holes at the intended size.
4. Subject-specific identity cues.
5. Smooth vector-quality outlines.
6. Traditional texture and auspicious ornament.

White holes may remain isolated inside the red sheet. Red islands may not remain isolated in a strict variant.

## Complexity defaults

| Level | Primary use | Minimum red bridge | Minimum useful white opening | Detail policy |
|---|---|---:|---:|---|
| simple | scissors, beginner | 2.5 mm | 3.0 mm | large silhouette cuts, sparse motifs |
| standard | scissors or knife | 2.0 mm | 2.5 mm | preserve recognition, simplify repetitive texture |
| fine | knife, larger work | 1.0 mm | 1.5 mm | denser motifs with careful bridges |

Treat these as conservative defaults for illustration paper. If a feature cannot meet the selected threshold, enlarge the long edge by `required threshold / measured feature`, round up to the next 10 mm, or simplify the feature.

## Subject rules

### People

- Preserve face shape, hairstyle, head angle, pose, body proportion, and distinctive accessories.
- Convert eyebrows, eyes, nose, mouth, and clothing folds into a few tapered crescent cuts and connected shapes.
- For strict two-color paper-cut characters, avoid red facial features floating inside a white face. Prefer a connected red head/face/hair mass with eyes, mouth, cheeks, and nose expressed as white negative-space cuts, or connect any red facial marks discreetly to adjacent red structure.
- Do not depersonalize, replace the person with a zodiac animal, or erase identity unless requested.
- Prefer enlarging before deleting a defining facial feature.

### Chibi, anime, mascots, and fantasy companions

- Preserve the character's silhouette, head-to-body proportion, pose, hair shape, hat, ornaments, and expression before preserving color design.
- Convert color blocks and shading into connected red masses and white cut-outs. Do not keep anime skin tones, blush colors, or colored eye fills.
- Treat floating companions, spirits, petals, stars, tassels, and small effects as structural risks. Connect them with a broad ribbon, cloud trail, flame trail, hair strand, sleeve, or ornament stem; otherwise merge, simplify, or omit them.
- Use white cut-outs for cute facial expression whenever possible. Red eye dots, red mouths, and detached cheek marks inside white areas must be avoided unless they are intentionally bridged.

### Architecture

- Preserve skyline, main massing, roof count, eave curvature, storey rhythm, symmetry, entrance, and landmark plaque position.
- Simplify repetitive railings, roof tiles, brackets, windows, foliage, and masonry into rhythmic connected bands.
- Use sawtooth cuts sparingly for roof tiles and foliage; use crescents or geometric openings for windows and clouds.
- Keep roof curves, wall silhouettes, columns, and large contour lines smooth. Do not let pixel stair-steps appear on eaves or skyline.
- Do not reproduce photographic watermarks or illegible signs. Preserve exact building text only when the user provides or confirms it.

### Animals and plants

- Preserve species silhouette, pose, gaze direction, and characteristic anatomy.
- Use sawtooth patterns for fur, feathers, scales, petals, or leaf edges without weakening structural bridges.

## Motifs

Infer motifs from the subject and context, while allowing user overrides. Do not force auspicious symbolism into neutral or unsuitable subjects. Prefer structural motifs over decorative clutter. Examples include clouds, peony, lotus, plum blossom, ruyi, geometric lattice, waves, and zodiac motifs.

## Composition

Keep the full source composition by default. Crop, isolate, remove background elements, or add a frame only when requested or when a minor element prevents a usable cut. Use a pure white artboard and no automatic square border.

## Output checks

- Use a pure white PNG background with red artwork. Preview PNG edges may be anti-aliased for visual smoothness; the SVG remains the authoritative cutting path.
- Use one closed filled red compound path in SVG, not strokes, open paths, clipping tricks, filters, gradients, or embedded raster images.
- Keep a white artboard behind the red path for consistent display.
- Remove tiny debris and accidental holes.
- Distinguish intentional Jianzhi sawtooth texture from unwanted pixel stair-stepping. Sawtooth texture must be deliberate, rhythmic, and local; outer contours and major curves must be smooth or cleanly straight.
- Do not rely on many automatic bridges to repair a fragmented master. For a standard strict output, more than 20 added bridges or more than 40 pre-bridge red components is a warning to regenerate with fewer detached details or to recommend a larger/simpler version.
- Visually compare the raster and SVG before delivery.
