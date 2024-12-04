import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';  // For decoding JSON responses
import 'package:vidvliveness_flutter_plugin/vidvliveness_flutter_plugin.dart';
import 'package:vidvocr_flutter_plugin/vidvocr_flutter_plugin.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR and Liveness Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _LivenessResult = 'No result yet';
  final _vidvlivenessFlutterPlugin = VidvlivenessFlutterPlugin();
  String _ocrResult = 'No result yet';
  final _vidvocrFlutterPlugin = VidvocrFlutterPlugin();

  final String _ocrText = "Start your EKYC Journey";
  final String username = "Enter you username";
  final String password = "Enter your password";
  final String clientId = "Enter your client Id";
  final String clientSecret = "Enter your clinet secret";
  final String bundleKey = 	"Enter your bundle key";
  final String language = "<insert_language>";
  String _accessToken = '';
  final String baseURL = 'Enter the base url';

  // Function to make the POST request and fetch the token
  Future<void> generateToken() async {
    final url = Uri.parse(baseURL+'api/o/token/');

    final response = await http.post(
      url,
      body: {
        'username': username,
        'password': password,
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'password'
      },
    );

    if (response.statusCode == 200) {
      // If the request is successful, decode the response and save the token
      var responseData = jsonDecode(response.body);
      setState(() {
        _accessToken = responseData['access_token']; // Saving the token ans setting it in the UI
      });
      startOCR(); // call OCR Function
    } else {
      setState(() {
        _accessToken = 'Failed to fetch token. Status code: ${response.statusCode}';
      });
    }
  }
  //Function to configure and start OCR
  Future<void> startOCR() async {
    final Map<String, dynamic> params = {
      //These are required configurations
      "base_url": baseURL,
      "access_token": _accessToken,
      "bundle_key": bundleKey,
      //This is an example of an optional configuration
      "language": language
    };
    try {
      // Call start OCR with the given parameters and save the json result
      final String? result = await VidvocrFlutterPlugin.startOCR(params);
      final parsedResult = jsonDecode(result!);
      //Handeling OCR Response
      if (parsedResult['nameValuePairs']['state'] == 'SUCCESS'){
        //Process finished successfully
        setState(() {
          _ocrResult = 'OCR success!';
          // Get transaction front ID to activate face match in liveness SDK
            final transactionIdFront = parsedResult['nameValuePairs']['ocrResult']['ocrResult']['transactionIdFront'];
            print('Transaction ID Front: $transactionIdFront');
            //Call liveness function on OCR Success
            startLiveness(transactionIdFront);
          });
      }
      else if (parsedResult['nameValuePairs']['state'] == 'ERROR') {
        //Process terminated due to an error in the builder
        setState(() {
          _ocrResult = 'OCR Error! ${parsedResult['nameValuePairs']['errorCode']} - ${parsedResult['nameValuePairs']['errorMessage']}';
        });
      }
      else if (parsedResult['nameValuePairs']['state'] == 'FAILURE') {
        //Process finished with the user's failure to pass the service requirements
        setState(() {
          _ocrResult =
          'Service failed. Error code: ${parsedResult['nameValuePairs']['errorCode']} - ${parsedResult['nameValuePairs']['errorMessage']}';
        });
      }
      else if (parsedResult['nameValuePairs']['state'] == 'EXIT') {
        //Process terminated by the user with no errors
        setState(() {
          _ocrResult = 'User exited at step: ${parsedResult['nameValuePairs']['step']}';
        });
      }
    } catch (e) {
      setState(() {
        _ocrResult= 'Error: $e';
      });
    }
  }

  //Function calling and configuring Liveness SDK
  Future<void> startLiveness(String transactionFrontId) async{
    Map<String, dynamic> params = {
      //These are required configurations
      'base_url': baseURL,
      'access_token': _accessToken,
      'bundle_key': bundleKey,
      //This is an example of optional configurations
      'language': 'en',
      "facematch_ocr_transactionId": transactionFrontId
    };

    try {
      //Calling Liveness SDK with given parameters and saving the result
      final String? result = await VidvlivenessFlutterPlugin.startLiveness(params);
      final parsedResult = jsonDecode(result!);

      //Handling Liveness SDK Response
      if (parsedResult["nameValuePairs"]["state"] == 'SUCCESS') {
        // Process finished successfully
        setState(() {
          _LivenessResult = "Liveness Success!";
        });
      }
      else if (parsedResult["nameValuePairs"]['state'] == 'ERROR') {
        //Process terminated due to an error in the builder
        setState(() {
          _LivenessResult = 'Liveness Error! ${parsedResult["nameValuePairs"]['errorCode']} - ${parsedResult["nameValuePairs"]['errorMessage']}';
        });
      }
      else if (parsedResult["nameValuePairs"]['state'] == 'FAILURE') {
        //Process finished with the user's failure to pass the service requirements
        setState(() {
          _LivenessResult =
          'Service failed. Error code: ${parsedResult["nameValuePairs"]['errorCode']} - ${parsedResult["nameValuePairs"]['errorMessage']}';
          //Handling face match error
          if (parsedResult["nameValuePairs"]["errorCode"]=='7201'){
            try {
              _showFaceNotMatchingAlert(transactionFrontId);
            } catch (e) {
              print('Error showing dialog: $e');
            }
          }
        });
      }
      else if (parsedResult["nameValuePairs"]['state'] == 'EXIT') {
        //Process terminated by the user with no errors
        setState(() {
          _LivenessResult = 'User exited at step: ${parsedResult['nameValuePairs']['step']}';
        });
      }
      } catch (e) {
      setState(() {
        _LivenessResult = 'Error: $e';
      });
    }
  }
  // Function to show alert when face doesn't match
  void _showFaceNotMatchingAlert(String transactionFrontId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Face Not Matching'),
          content: Text('The face does not match the transaction ID.'),
          actions: <Widget>[
            TextButton(
              child: Text('Try Liveness Again'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the alert dialog
                startLiveness(transactionFrontId); // Try Liveness again
              },
            ),
            TextButton(
              child: Text('Restart OCR and Liveness'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the alert dialog
                startOCR(); // Restart the whole process
              },
            ),
          ],
        );
      },
    );
  }

  //Application UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("OCR and Liveness Integration"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _ocrText,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                generateToken();
              },
              child: Text("Start OCR"),
            ),
            SizedBox(height: 20),
            Text('Access Token: $_accessToken'),//Displaying access token on UI
            Text('OCR Result:$_ocrResult'),//Displaying OCR result on UI
            Text ("Liveness Result: $_LivenessResult"), //Displaying Liveness result in UI
          ],
        ),
      ),
    );
  }
}