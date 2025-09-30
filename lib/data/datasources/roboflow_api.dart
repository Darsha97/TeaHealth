// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;

// class RoboflowApi {
//   static const String _apiKey = 'hQeGEX7aLVk0INzfnwkQ';
//   static const String _modelUrl = 'https://serverless.roboflow.com/tea-leave-disease-detection/1';

//   static Future<Map<String, dynamic>?> predict(File imageFile) async {
//     try {
//       final bytes = await imageFile.readAsBytes();
//       final base64Image = base64Encode(bytes);

//       // ✅ PREPEND the proper MIME type
//       final dataUri = 'data:image/jpeg;base64,$base64Image';

//       final response = await http.post(
//         Uri.parse('$_modelUrl?api_key=$_apiKey'),
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//         body: {'image': dataUri},
//       );

//       if (response.statusCode == 200) {
//         print('✅ Prediction Success');
//         return json.decode(response.body);
//       } else {
//         print('❌ Prediction failed: ${response.statusCode}');
//         print(response.body);
//         return null;
//       }
//     } catch (e) {
//       print('❌ Exception: $e');
//       return null;
//     }
//   }
// }


// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:mime/mime.dart';

// class RoboflowApi {
//   static const String _apiKey = 'hQeGEX7aLVk0INzfnwkQ';
//   static const String _modelUrl = 'https://serverless.roboflow.com/tea-leave-disease-detection/1';

//   static Future<Map<String, dynamic>?> predict(File imageFile) async {
//     try {
//       // ✅ Read file as bytes (Uint8List)
//       final Uint8List imageBytes = await imageFile.readAsBytes();

//       if (imageBytes.isEmpty) {
//         print('❌ Image is empty');
//         return null;
//       }

//       // ✅ Detect MIME type (jpeg or png)
//       final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

//       // ✅ Encode to Base64
//       final base64Image = base64Encode(imageBytes);
//       final String dataUri = 'data:image/jpeg;base64,$base64Image';
//       //final dataUri = 'data:$mimeType;base64,$base64Image';

//       print('🛠 Sending to: $_modelUrl');
//       print('🖼 MIME type: $mimeType');
//       print('📎 Base64 length: ${base64Image.length}');

//       // ✅ Send POST request
//       final response = await http.post(
//         Uri.parse('$_modelUrl?api_key=$_apiKey'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'image': dataUri}),
//       );

//       // ✅ Handle result
//       if (response.statusCode == 200) {
//         print('✅ Prediction Success');
//         return jsonDecode(response.body);
//       } else {
//         print('❌ Prediction failed: ${response.statusCode}');
//         print(response.body);
//         return null;
//       }
//     } catch (e) {
//       print('❌ Exception: $e');
//       return null;
//     }
//   }
// }



import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<List<dynamic>> getInferenceResults(Uint8List imageBytes, String apiKey, String modelEndpoint) async {
  final base64Image = base64Encode(imageBytes);
  final imageData = 'data:image/jpeg;base64,$base64Image';
  final apiUrl = '$modelEndpoint?api_key=$apiKey';

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'image': imageData,
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['predictions']; // or adjust depending on your model output
    } else {
      print("❌ Error ${response.statusCode}: ${response.body}");
      return [];
    }
  } catch (e) {
    print("❌ Exception: $e");
    return [];
  }
}
