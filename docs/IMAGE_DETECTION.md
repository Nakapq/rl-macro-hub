# Deferred: visual movement-state detection

Decision recorded 2026-10-22: defer implementation until the input-driven
Multi-Directional running mode has a verified stable baseline. No capture,
model dependencies, training pipeline, or image-detection mode is enabled.

## Motivation and limits

The runtime's Run HUD reports its own macro state, not a measured Roblox state.
Regular running, mana running, and climbing play character animations. Mana
running also leaves a potentially faint trail. Climbing stops running, but
Space alone cannot establish whether the character actually climbed a wall.
These game-driven changes cannot always be inferred from player inputs.

This is animation recognition rather than OCR. Prefer body animation when it
distinguishes the states; use the mana trail as supporting evidence. If two
states are visually identical from the current perspective, no image model
can reliably distinguish them. First-person views, occlusion, distant avatars,
and ambiguous transitions must allow an unknown result.

## Candidate implementation, subject to a prototype

- Windows.Graphics.Capture: acquire Roblox window frames.
- OpenCvSharp: crop/resize frames and optional motion features in C#.
- PyTorch/TorchVision: fine-tune a pretrained image or short-video classifier
  on labeled gameplay. Compare a small frame classifier with a temporal model;
  longer clips can improve animation recognition but add detection latency.
- ONNX Runtime: run the exported model locally in the C# application.
- Keep capture/inference off the AHK input path. Inputs provide an immediate
  estimate; observations can later reconcile it using timestamps, freshness
  checks, and consistent evidence. Unknown/stale observations must not cancel
  a run or automatically restart one. Model scores are not guaranteed accuracy.

Start with observation-only climbing detection, then evaluate regular versus
mana running. Optical flow may provide supporting motion information, but
camera/background movement makes it insufficient as the sole state detector.

## Training and evaluation plan

1. Record actual animation states: idle/walking, regular running, mana running,
   climbing, jumping/falling, and transitions. Do not derive labels solely
   from key presses. Mark uncertain intervals separately.
2. Record each state across rear/front/side/diagonal views, low/high camera
   angles, near/far zoom, and moving cameras. Vary outfits, equipment, lighting,
   backgrounds, graphics settings, and nearby players. Avoid associating one
   state with a particular camera or location.
3. Include hard negatives: jumping beside a wall, running into a wall without
   climbing, falling beside a wall, faint mana effects, and running in place.
4. Use the same player-location/cropping method in training and deployment.
   Leave margin for limbs and effects. A fixed center crop is only suitable
   if actual camera behavior keeps the player's character inside it.
5. Apply realistic brightness/contrast, crop, scale, and blur augmentation.
   Keep spatial augmentation consistent across video frames. Image warping
   cannot substitute for recordings of real alternate 3D viewpoints.
6. Split by complete recording session before extracting overlapping clips.
   Adjacent frames must not leak across training/validation/test sets. Reserve
   unseen sessions, outfits, and camera conditions for generalization tests.
7. Measure false run cancellations, missed climbs/stops, transition delay,
   unknown rate, inference cost, and results by camera view. Evaluate continuous
   sessions as well as isolated clips. Tune on validation data; preserve a
   separate final test set. Collect more examples of observed failures.

## Gates before enabling a future variant

- Complete the input-only [stability checklist](MANA_RUNNING.md#stability-validation).
- Prove usefulness in observation-only logs against manually reviewed footage.
- Agree on acceptable false-cancellation rates and delay based on measurements.
- Verify safe unknown/stale behavior and no interference with input timing.
- Introduce an optional variant only after those gates; keep the stable
  input-driven mode available.

## References

- [Windows capture](https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/screen-capture)
- [OpenCvSharp](https://github.com/shimat/opencvsharp)
- [PyTorch transfer learning](https://docs.pytorch.org/tutorials/beginner/transfer_learning_tutorial.html)
- [TorchVision video models](https://docs.pytorch.org/vision/stable/models/generated/torchvision.models.video.r3d_18.html)
- [TorchVision augmentation](https://docs.pytorch.org/vision/stable/transforms.html)
- [Grouped validation splits](https://scikit-learn.org/stable/modules/cross_validation.html)
- [ONNX Runtime for C#](https://onnxruntime.ai/docs/get-started/with-csharp)
