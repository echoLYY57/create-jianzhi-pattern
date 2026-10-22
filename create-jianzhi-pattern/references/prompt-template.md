# Raster master prompt

Use the built-in image generation tool. Treat an uploaded image as a composition and subject-identity reference, not as a surface texture.

```text
Use case: style-transfer
Asset type: printable Chinese Jianzhi paper-cut master for hand scissors or craft knife, plus social-media illustration
Primary request: transform the reference into a standard-complexity, physically cuttable Chinese paper-cut while preserving the recognizable subject and the full original composition
Input image: Image 1 is the composition, silhouette, identity, pose, and landmark reference
Style/medium: authentic flat Chinese Jianzhi; solid matte Chinese red paper shapes on absolute white; smooth vector-quality outer contours; crisp graphic edges; traditional sawtooth and crescent cuts used selectively only as intentional internal texture
Composition: preserve the main subject, viewpoint, proportions, landmark features, and scene hierarchy; no outer frame unless requested
Structure: all red positive areas form one continuous sheet; use discreet bridges; white negative spaces are intentional cut-outs; simplify repeated micro-detail before sacrificing recognition; avoid pixel stair-step outlines
Motifs: infer culturally appropriate motifs from the subject and context; user-specified motifs override inference
Text: reproduce only exact user-confirmed wording; otherwise remove watermarks, signatures, timestamps, and unreadable lettering
Colors: exactly #D9381E and #FFFFFF; no other colors
Constraints: flat binary graphic, closed bold shapes, standard hand-cut detail, generous usable spacing, no detached red islands
Avoid: photography, realistic lighting, perspective depth effects beyond the recognizable silhouette, gradients, shading, shadows, paper grain, blurry antialias haze, pixelated stair-step edges, raster jaggies, 3D, multiple colors, thin hairlines, floating pieces, broken bridges, square frame, watermark, signature, invented text
```

For architecture, append:

```text
Preserve the building's skyline, roof and eave rhythm, storey hierarchy, frontal symmetry, entrance, and landmark plaque placement. Keep large eave curves and roof silhouettes smooth, not staircase-pixelated. Abstract railings, roof tiles, brackets, windows, trees, and stonework into fewer connected rhythmic bands. Do not reproduce photographic watermark text.
```

For people, append:

```text
Preserve the person's identity through face contour, hairstyle, head angle, pose, body proportion, and distinctive accessories. Express facial features with a small number of tapered negative-space cuts. Do not replace or depersonalize the person.
```

For chibi, anime, mascot, or fantasy-character illustrations, append:

```text
Preserve the character identity through silhouette, head-to-body proportion, pose, hairstyle, hat, ornaments, companion character, and expression. Convert the face/head into connected red paper masses with eyes, mouth, and key expression marks as white negative-space cuts; avoid red eye or mouth islands floating inside a white face. Connect floating companions, petals, tassels, stars, and effects to the main character with a broad ribbon, cloud trail, flame trail, hair strand, sleeve, or ornament stem, or simplify them away.
```

For text-only generation, replace the input-image line with a concise subject, action, composition, and requested motifs. Infer omitted visual choices conservatively.
