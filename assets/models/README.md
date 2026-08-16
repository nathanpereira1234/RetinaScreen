# On-device diabetic-retinopathy model

Drop a TensorFlow Lite model here named **`dr_model.tflite`**. Until you do, the
app still runs — the "AI assist" card just reports the model is unavailable.

> **Design note.** This is *decision support*, not diagnosis. The model only
> suggests a grade; a health worker confirms the result before it is saved. See
> `lib/services/retinopathy_grader.dart` and B08 in the top-level README. Adding
> an autonomous (no-human) diagnosis path changes the app's regulatory class
> (SaMD) — don't do it without clearing that first.

## What the code expects

`RetinopathyGrader` (in `lib/services/retinopathy_grader.dart`) assumes:

| Property | Default | Where to change |
|---|---|---|
| Input | `[1, 224, 224, 3]` float RGB | `_inputSize` |
| Normalisation | `(pixel - 0) / 255` → `[0,1]` | `_mean` / `_std` |
| Output | `[1, 5]` scores for APTOS grades 0–4 | `_numClasses` |

Grade → clinical action mapping (`RetinopathyPrediction.suggestedResult`):

- `0 No DR`, `1 Mild` → **not referable**
- `2 Moderate`, `3 Severe`, `4 Proliferative` → **referable**
- confidence < 0.5 → **ungradable** (re-screen; never a false "not referable")

**If your model differs** (different input size, ImageNet mean/std, or a
different number of classes), update those constants — a preprocessing mismatch
silently destroys accuracy.

## Where to get a pre-trained model

Any classifier trained on the public **APTOS 2019 Blindness Detection** or
**EyePACS** datasets works. Typical backbones: EfficientNet-B0/B3, ResNet50.

1. Grab a trained Keras/PyTorch model (Kaggle notebooks and Hugging Face both
   have APTOS DR classifiers), or train your own.
2. Convert to TFLite. From a Keras `SavedModel`:

   ```python
   import tensorflow as tf
   conv = tf.lite.TFLiteConverter.from_saved_model("saved_model_dir")
   conv.optimizations = [tf.lite.Optimize.DEFAULT]   # smaller, quantised
   open("dr_model.tflite", "wb").write(conv.convert())
   ```

   (PyTorch → export to ONNX → `onnx2tf` or `onnx-tf` → TFLite.)
3. Copy the result here as `dr_model.tflite`, then `flutter pub get` and
   `flutter run`.

## Verifying

Open a patient → **Record screening** → **AI assist**, pick a fundus image, and
confirm a grade + confidence appears. Sanity-check a few known images before
trusting it — a converted model with the wrong normalisation will still return
confident-looking nonsense.
