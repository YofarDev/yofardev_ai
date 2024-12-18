import 'package:llm_api_picker/llm_api_picker.dart';

class Test {
  static FunctionInfo multiStepsFunction = FunctionInfo(
    name: 'multiStepsFunction',
    description: 'This is the 1/3 step function',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'password': <String, dynamic>{
          'type': 'string',
          'description': 'The password needed to access next step',
        },
      },
    },
    function: (String password) async {
      if (password == 'banana') {
        return Future<String>.value('Success. Next password is : "supernova"');
      } else {
        return 'Wrong password';
      }
    },
    nextStep: FunctionInfo(
      name: 'multiStepsFunction2',
      description: 'This is the 2/3 step function',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'password': <String, dynamic>{
            'type': 'string',
            'description': 'The password needed to access next step',
          },
        },
      },
      function: (String password) async {
        if (password == 'supernova') {
          return Future<String>.value(
            'Success. Next password is : "banana"',
          );
        } else {
          return 'Wrong password';
        }
      },
      nextStep: FunctionInfo(
        name: 'multiStepsFunction3',
        description: 'This is the 3/3 step function',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'password': <String, dynamic>{
              'type': 'string',
              'description': 'The password needed to access next step',
            },
          },
        },
        function: (String password) async {
          if (password == 'banana') {
            return Future<String>.value('The secret is : Alyssa Milano');
          } else {
            return 'Wrong password';
          }
        },
      ),
    ),
  );
}
