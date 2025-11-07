package com.example.teascan_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.pytorch.IValue
import org.pytorch.Module
import org.pytorch.Tensor
import org.pytorch.torchvision.TensorImageUtils
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val CHANNEL = "pytorch_channel"
    private var module: Module? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            module = Module.load(assetFilePath("efficientnetb3_traced_mobile.pt"))
            Log.d("Pytorch", "✅ Model loaded successfully")
        } catch (e: IOException) {
            Log.e("Pytorch", "❌ Failed to load model", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "runModel") {
                val imagePath = call.argument<String>("path")
                Log.d("Pytorch", "📸 Image path received: $imagePath")

                if (imagePath == null) {
                    result.error("INVALID_ARGUMENT", "No image path provided", null)
                    return@setMethodCallHandler
                }

                // Decode bitmap with options to handle large images
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = false
                    inSampleSize = 1
                }
                var bitmap = BitmapFactory.decodeFile(imagePath, options)
                if (bitmap == null) {
                    result.error("BITMAP_ERROR", "Failed to decode bitmap from: $imagePath", null)
                    return@setMethodCallHandler
                }
                
                // Handle EXIF orientation for camera photos - improved handling
                try {
                    val exif = ExifInterface(imagePath)
                    val orientation = exif.getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL
                    )
                    
                    Log.d("Pytorch", "📐 EXIF orientation: $orientation")
                    
                    if (orientation != ExifInterface.ORIENTATION_NORMAL) {
                        val matrix = Matrix()
                        when (orientation) {
                            ExifInterface.ORIENTATION_ROTATE_90 -> {
                                matrix.postRotate(90f)
                                Log.d("Pytorch", "🔄 Rotating 90°")
                            }
                            ExifInterface.ORIENTATION_ROTATE_180 -> {
                                matrix.postRotate(180f)
                                Log.d("Pytorch", "🔄 Rotating 180°")
                            }
                            ExifInterface.ORIENTATION_ROTATE_270 -> {
                                matrix.postRotate(270f)
                                Log.d("Pytorch", "🔄 Rotating 270°")
                            }
                            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> {
                                matrix.postScale(-1f, 1f)
                                Log.d("Pytorch", "🔄 Flipping horizontally")
                            }
                            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                                matrix.postScale(1f, -1f)
                                Log.d("Pytorch", "🔄 Flipping vertically")
                            }
                            ExifInterface.ORIENTATION_TRANSPOSE -> {
                                matrix.postRotate(90f)
                                matrix.postScale(-1f, 1f)
                                Log.d("Pytorch", "🔄 Transpose (90° + flip)")
                            }
                            ExifInterface.ORIENTATION_TRANSVERSE -> {
                                matrix.postRotate(270f)
                                matrix.postScale(-1f, 1f)
                                Log.d("Pytorch", "🔄 Transverse (270° + flip)")
                            }
                        }
                        
                        try {
                            val rotatedBitmap = Bitmap.createBitmap(
                                bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
                            )
                            if (rotatedBitmap != bitmap) {
                                bitmap.recycle()
                                bitmap = rotatedBitmap
                                Log.d("Pytorch", "✅ EXIF rotation applied. New size: ${bitmap.width}x${bitmap.height}")
                            }
                        } catch (e: Exception) {
                            Log.e("Pytorch", "❌ Failed to apply rotation: ${e.message}")
                            // Continue with original bitmap if rotation fails
                        }
                    } else {
                        Log.d("Pytorch", "✓ No EXIF rotation needed")
                    }
                } catch (e: Exception) {
                    Log.w("Pytorch", "⚠️ Could not read EXIF data: ${e.message}")
                    // Continue with original bitmap if EXIF read fails
                }

                if (module == null) {
                    result.error("MODEL_ERROR", "Model not loaded", null)
                    return@setMethodCallHandler
                }

                try {
                    Log.d("Pytorch", "🔄 Resizing bitmap... Original size: ${bitmap.width}x${bitmap.height}")
                    val resized = Bitmap.createScaledBitmap(bitmap, 300, 300, true)
                    
                    // Recycle original bitmap if we created a resized version
                    if (resized != bitmap) {
                        bitmap.recycle()
                    }

                    Log.d("Pytorch", "🔄 Converting to tensor...")
                    val inputTensor = TensorImageUtils.bitmapToFloat32Tensor(
                        resized,
                        TensorImageUtils.TORCHVISION_NORM_MEAN_RGB,
                        TensorImageUtils.TORCHVISION_NORM_STD_RGB
                    )
                    
                    // Recycle resized bitmap after creating tensor
                    resized.recycle()

                    Log.d("Pytorch", "🤖 Running inference...")
                    val outputs = module!!.forward(IValue.from(inputTensor)).toTuple()
                    val outputTensor = outputs[0].toTensor()

                    val classIndices = outputTensor.dataAsLongArray
                    Log.d("Pytorch", "📊 Output class indices: ${classIndices.joinToString()}")

                    val predictedClass = classIndices[0].toInt()
                    val label = if (predictedClass == 0) "Non-Tea" else "Tea"
                    val confidence = 1.0  // you can update if your model returns softmax in another output

                    val response = "{\"label\":\"$label\",\"confidence\":$confidence}"
                    Log.d("Pytorch", "✅ Prediction result: $response")
                    result.success(response)

                } catch (e: Exception) {
                    Log.e("Pytorch", "🔥 Error during model inference", e)
                    result.error("MODEL_ERROR", "Error running model: ${e.message}", e.stackTraceToString())
                }
            } else {
                result.notImplemented()
            }
        }
    }

    @Throws(IOException::class)
    private fun assetFilePath(assetName: String): String {
        val file = File(filesDir, assetName)
        if (file.exists() && file.length() > 0) {
            return file.absolutePath
        }

        assets.open(assetName).use { inputStream ->
            FileOutputStream(file).use { outputStream ->
                val buffer = ByteArray(4096)
                var read: Int
                while (inputStream.read(buffer).also { read = it } != -1) {
                    outputStream.write(buffer, 0, read)
                }
                outputStream.flush()
            }
        }

        return file.absolutePath
    }
}