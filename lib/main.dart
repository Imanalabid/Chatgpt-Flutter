import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:text_to_speech/text_to_speech.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var results = "results...";
  late ChatGPT openAI;
  TextEditingController textEditingController = TextEditingController();

  List<ChatMessage> messages = [];
  ChatUser user = ChatUser(id: "1",firstName: "Hamza",lastName: "Asif");
  ChatUser openGpt = ChatUser(id: "2",firstName: "OPENAI",lastName: "CHATGPT");

  late TextToSpeech tts;
  bool isTTS = false;
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool isDark = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    openAI = ChatGPT.instance.builder(
        "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",
        baseOption: HttpSetup(receiveTimeout: 16000));

    tts = TextToSpeech();
    _initSpeech();
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    if(result.finalResult) {
      setState(() {
        textEditingController.text = result.recognizedWords;
        performAction();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //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
    return Scaffold(
      appBar: AppBar(
        title: Text("ChatGPT"),centerTitle: true,actions: [
          InkWell(
            onTap: (){
               setState(() {
                 if(isTTS){
                   isTTS = false;
                   tts.stop();
                 }else{
                   isTTS = true;
                 }
               });
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(isTTS?Icons.record_voice_over:Icons.voice_over_off_sharp,),
            ),
          )
      ],leading: InkWell(child: Icon(Icons.light_mode),onTap: (){
        setState(() {
          if(isDark){
            isDark = false;
          }else{
            isDark = true;
          }
        });
      },),
      ),
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage('images/bg.jpg'),
                fit: BoxFit.cover,invertColors: isDark)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: DashChat(
                  currentUser: user,
                  onSend: (ChatMessage m) {
                    setState(() {
                      messages.insert(0, m);
                    });
                  },
                  messages: messages,readOnly: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                        child: Card(
                          color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius:
                            BorderRadius.circular(25)),
                            child: Padding(
                              padding: const EdgeInsets.only(left:14.0),
                              child: TextField(
                      controller: textEditingController,decoration: const InputDecoration(
                                border: InputBorder.none,hintText: "type anything here.."
                              ),
                    ),
                            ))),
                    ElevatedButton(
                      onPressed: () {
                       _startListening();
                      },
                      child: Icon(Icons.mic),
                      style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                          backgroundColor: Colors.blue),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        performAction();
                      },
                      child: Icon(Icons.send),
                      style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                          backgroundColor: Colors.blue),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  performAction(){
    ChatMessage msg = ChatMessage(user: user, createdAt: DateTime.now(),text: textEditingController.text);
    setState(() {
      messages.insert(0,msg);
    });

    if(textEditingController.text.toLowerCase().startsWith("generate image")){
      final request = GenerateImage(textEditingController.text,2,size: "256x256");

      openAI.generateImageStream(request)
          .asBroadcastStream()
          .first.then((it) {
        print(it.data?.last?.url);
        for(var imgData in it.data!){
          ChatMessage msg = ChatMessage(user: openGpt,
              createdAt: DateTime.now(),
              text: "Image",medias: [ChatMedia(url: imgData!.url!, fileName: "image", type: MediaType.image)]);
          setState(() {
            messages.insert(0, msg);
          });
        }

      });
    }else {
      final request = CompleteReq(
          prompt: textEditingController.text,
          model: "text-davinci-003",
          max_tokens: 200);

      openAI
          .onCompleteStream(request: request)
          .first
          .then((response) {
            print(response!.model);
        ChatMessage msg = ChatMessage(user: openGpt,
            createdAt: DateTime.now(),
            text: response!.choices!.first!.text!.trim());
        setState(() {
          messages.insert(0, msg);
        });
        if(isTTS) {
          tts.speak(response!.choices!.first!.text!.trim());
        }
      });
    }
    textEditingController.clear();
    modelDataList();
  }

  void modelDataList() async{
    final model = await ChatGPT.instance
        .builder("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")
        .listModel();
    for(var model in model.data){
      print(model.id+"  "+model.owned_by);
    }
  }
}
