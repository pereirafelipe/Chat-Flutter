import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  /*
  Escrever
  FirebaseFirestore.instance.collection("mensagens").doc().set({"texto":"iae", "from":"Rodrigo"});
  FirebaseFirestore.instance.collection("mensagens").doc().set({"texto":"iae", "from":"Pereira"});

  Ler
  QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('mensagens').get();
  print("Teste");
  for(QueryDocumentSnapshot<Map<String, dynamic>> li in snapshot.docs){
    print(li.data());
  }
  print(snapshot.docs.length);*/

  /*
  Ler sem await
  FirebaseFirestore.instance.collection("mensagens").snapshots().listen((snapshot) {
    for(QueryDocumentSnapshot<Map<String, dynamic>> li in snapshot.docs){
      print(li.data());
    }
  });*/

  runApp(const MyApp());
}

final ThemeData kDefaultTheme = ThemeData(
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.purple).copyWith(secondary: Colors.orangeAccent[400])
);

final googleSingIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<void> _ensureLoggedIn() async {
  GoogleSignInAccount? user = googleSingIn.currentUser;
  user ??= await googleSingIn.signInSilently();
  user ??= await googleSingIn.signIn();
  if(auth.currentUser==null){
    GoogleSignInAuthentication credentials = await googleSingIn.currentUser!.authentication;
    await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: credentials.idToken, accessToken: credentials.accessToken));
  }
}

_handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

void _sendMessage({String? text, String? imgUrl}) async {
  QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('mensagens').get();
  FirebaseFirestore.instance.collection("mensagens").doc(snapshot.docs.length.toString()).set({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": googleSingIn.currentUser!.displayName,
    "senderPhotoUrl": googleSingIn.currentUser!.photoUrl
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat Online",
      debugShowCheckedModeBanner: false,
      theme: kDefaultTheme,
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      top: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chat App"),
          centerTitle: true,
          elevation: 4.0,
        ),
        body: Column(
          children: [
            Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance.collection("mensagens").snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    switch(snapshot.connectionState){
                      case ConnectionState.none:
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      case ConnectionState.waiting:
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        return ListView.builder(
                          reverse: true,
                          itemCount: snapshot.data.docs.length,
                          itemBuilder: (context, index){
                            List r =snapshot.data.docs.reversed.toList();
                            return ChatMessage(r[index].data());
                          },
                        );
                    }
                  },
                )
            ),
            const Divider(
              height: 1,
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: const TextComposer(),
            )
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  const TextComposer({Key? key}) : super(key: key);

  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final _textController = TextEditingController();
  bool _isComposing = false;

  void _rest(){
    _textController.clear();
    setState(() {
      _isComposing=false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
        data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo_camera),
                onPressed: () async {
                  _ensureLoggedIn();
                  XFile? imgFile = await ImagePicker().pickImage(
                      source: ImageSource.camera);
                  if (imgFile == null) return;
                  Task task = FirebaseStorage.instance.ref().child(googleSingIn.currentUser!.id.toString() +
                      DateTime.now().millisecondsSinceEpoch.toString()).putFile(File(imgFile.path));
                  TaskSnapshot taskSnapshot = await task;
                  String url = await taskSnapshot.ref.getDownloadURL();
                  _sendMessage(imgUrl: url);
                  }
                ),
              Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration.collapsed(hintText: "Enviar mensagem"),
                    onChanged: (text){
                      setState(() {
                        _isComposing = text.isNotEmpty;
                      });
                    },
                    onSubmitted: (text){
                      _handleSubmitted(text);
                      _rest();
                    },
                  )
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isComposing ? (){
                    _handleSubmitted(_textController.text);
                    _rest();
                  }:null,
                ),
              )
            ],
          ),
        )
    );
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ChatMessage(this.data, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data["senderName"], style: Theme.of(context).textTheme.subtitle1,),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  child: data["imgUrl"] !=null? Image.network(data["imgUrl"], width: 250,):
                  Text(data["text"]),
                )
              ],
            )
          )
        ],
      ),
    );
  }
}
