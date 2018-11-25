import 'dart:async';

import 'package:chitchat/login/register.dart';
import 'package:chitchat/login/welcome.dart';
import 'package:chitchat/common/imageResolution.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:chitchat/const.dart';
import 'package:chitchat/overview/overview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChitChat',
      theme: new ThemeData(
        primaryColor: Colors.amber,
      ),
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  LoginScreenState createState() => new LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = new GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final passController = TextEditingController();

  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  FirebaseUser currentUser;

  FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    isSignedIn();
    initFlutterLocalNotifications();
    initFirebaseMessaging();
    initFireStore();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                MainScreen(currentUserId: prefs.getString('id'))),
      );
    }

    this.setState(() {
      isLoading = false;
    });
  }

  void initFireStore() {
    Firestore.instance.settings(timestampsInSnapshotsEnabled: true);
  }

  void initFlutterLocalNotifications() {
    var initializationSettingsAndroid =
    new AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future _showNotificationWithDefaultSound(Map<String, dynamic> message) async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'your channel id', 'your channel name', 'your channel description',
        importance: Importance.Max, priority: Priority.High);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      message['notification']['title'],
      message['notification']['body'],
      platformChannelSpecifics,
      payload: 'Default_Sound',
    );
  }

  void initFirebaseMessaging() {
    _firebaseMessaging.setAutoInitEnabled(true);
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) {
        print('on message $message');
        _showNotificationWithDefaultSound(message);
      },
      onResume: (Map<String, dynamic> message) {
        print('on resume $message');
      },
      onLaunch: (Map<String, dynamic> message) {
        print('on launch $message');
      },
    );

    _firebaseMessaging.getToken().then((token) async{
      print(token);
      prefs = await SharedPreferences.getInstance();
      prefs.setString("notificationToken", token);
    });
  }

  Future<Null> handleSignIn(String logintype) async {
    prefs = await SharedPreferences.getInstance();

    this.setState(() {
      isLoading = true;
    });
    FirebaseUser firebaseUser;
    if(logintype == 'google') {
      GoogleSignInAccount googleUser = await googleSignIn.signIn();
      GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      firebaseUser = await firebaseAuth.signInWithGoogle(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    }
    else {
      firebaseUser = await firebaseAuth.signInWithEmailAndPassword(
          email: emailController.text, password: passController.text)
          .catchError((e) {
        Fluttertoast.showToast(msg: "Sign in fail");
      });
    }
    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result = await Firestore.instance
          .collection('users')
          .where('id', isEqualTo: firebaseUser.uid)
          .getDocuments();
      final List<DocumentSnapshot> documents = result.documents;
      if (documents.length == 0) {
        // Update data to server if new user


        // Write data to local
        currentUser = firebaseUser;
        await prefs.clear();
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('nickname', currentUser.displayName);
        await prefs.setString('photoUrl', currentUser.photoUrl);
        await prefs.setString('photosResolution',
            ImageResolution.full.toString().split('.').last);

        Fluttertoast.showToast(msg: "Sign in success");
        this.setState(() {
          isLoading = false;
        });


        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => WelcomeScreen(
                currentUserId: firebaseUser.uid,
              )),
        );

      } else {
        // Write data to local
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('nickname', documents[0]['nickname']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
        await prefs.setString('photosResolution', documents[0]['photosResolution']);

        Fluttertoast.showToast(msg: "Sign in success");
        this.setState(() {
          isLoading = false;
        });

        if (documents[0]['nickname'].toString().length == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => WelcomeScreen(
                  currentUserId: firebaseUser.uid,
                )),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    MainScreen(
                      currentUserId: firebaseUser.uid,
                    )),
          );
        }
      }

    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    final email = TextFormField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      autofocus: false,
      decoration: InputDecoration(
        hintText: 'Email',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
      ),
    );

    final password = TextFormField(
      controller: passController,
      autofocus: false,
      obscureText: true,
      decoration: InputDecoration(
        hintText: 'Password',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
      ),
    );

    final loginButton = Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: FlatButton(
          onPressed: () => handleSignIn('email'),
          child: Text(
            'SIGN IN',
            style: TextStyle(fontSize: 16.0, color: Colors.black),
          ),
          color: Colors.amber,
          highlightColor: Colors.blueGrey,
          splashColor: Colors.transparent,
          textColor: Colors.white,
          padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)),
    );

    final GoogleLogin = Padding(
      padding: EdgeInsets.symmetric(vertical: 0.0),
      child: FlatButton(
          onPressed: () => handleSignIn('google'),
          child: Text(
            'CONNECT WITH GOOGLE',
            style: TextStyle(fontSize: 16.0, color: Colors.black),
          ),
          color: Colors.blueGrey,
          highlightColor: Colors.white30,
          splashColor: Colors.transparent,
          textColor: Colors.white,
          padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0)),
    );

    final registerButton = FlatButton(
        child: Text(
          'Create Account',
          style: TextStyle(color: Colors.black54),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterScreen()),
          );
        }

    );

    return Stack(
    children: <Widget>[
      Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(left: 24.0, right: 24.0),
            children: <Widget>[
              email,
              SizedBox(height: 8.0),
              password,
              SizedBox(height: 24.0),
              loginButton,
              GoogleLogin,
              registerButton,
            ],
          ),
        ),
      ),
      Positioned(
        child: isLoading
            ? Container(
          child: Center(
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)),
          ),
          color: Colors.white.withOpacity(0.8),
        )
            : Container(),
      ),
    ],
    );
  }
}
