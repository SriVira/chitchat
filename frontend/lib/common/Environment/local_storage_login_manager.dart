import 'dart:convert';

import 'package:codable/codable.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chitchat/common/Environment/login_manager.dart';
import 'package:chitchat/common/Models/user.dart';

//Concrete implementation of LoginManager using SharedPreferences as local storage.
class LocalStorageLoginManager implements LoginManager {

  static LocalStorageLoginManager _instance;

  //Singleton getter accessible as LocalStorageLoginManager.shared
  static Future<LocalStorageLoginManager> get shared async {
    if (!LocalStorageLoginManager._isInitialized()) {
      await LocalStorageLoginManager._initializeFields();
    }
    return LocalStorageLoginManager._instance;
  }

  SharedPreferences _prefs;

  LocalStorageLoginManager._private();

  static bool _isInitialized() {
    return LocalStorageLoginManager._instance != null;
  }

  static Future<void> _initializeFields() async {
    LocalStorageLoginManager._instance = LocalStorageLoginManager._private();
    LocalStorageLoginManager._instance._prefs = await SharedPreferences.getInstance();
  }

  //Singleton public methods

  bool isUserLogged() {
    return this.getUserLogged() != null;
  }

  User getUserLogged() {

    var existingUser = this._prefs.get("user");

    if (existingUser == null) return null;

    return User()..decode(KeyedArchive.unarchive(json.decode(existingUser)));
  }

  User setUserLogged({@required User user, bool forced}) {

    var existingUser = this._prefs.get("user");

    if (existingUser != null && !forced) throw LoginManagerException.userExistingException;

    this._prefs.setString("user", json.encode(KeyedArchive.archive(existingUser)));

    if (existingUser == null) return null;
    return User()..decode(KeyedArchive.unarchive(json.decode(existingUser)));
  }
}
