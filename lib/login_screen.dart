import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db_helper.dart';
import '../models/user.dart';
import 'currency_exchanger.dart';
import '../widgets/flag_language_selector.dart';
import '../widgets/theme_toggle_button.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'superadmin_screen.dart';  // Import the superadmin screen

// Global variable to store the currently logged in user
UserModel? currentUser; 