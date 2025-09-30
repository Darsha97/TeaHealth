package com.example.teascan_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
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

                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap == null) {
                    result.error("BITMAP_ERROR", "Failed to decode bitmap from: $imagePath", null)
                    return@setMethodCallHandler
                }

                if (module == null) {
                    result.error("MODEL_ERROR", "Model not loaded", null)
                    return@setMethodCallHandler
                }

                try {
                    Log.d("Pytorch", "🔄 Resizing bitmap...")
                    val resized = Bitmap.createScaledBitmap(bitmap, 300, 300, true)

                    Log.d("Pytorch", "🔄 Converting to tensor...")
                    val inputTensor = TensorImageUtils.bitmapToFloat32Tensor(
                        resized,
                        TensorImageUtils.TORCHVISION_NORM_MEAN_RGB,
                        TensorImageUtils.TORCHVISION_NORM_STD_RGB
                    )

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