import 'dart:async';
import 'package:budget_zen/services/firebase/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../services/firebase/messaging.dart';
import 'Redirection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Illustration de gestion financière.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.darken,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: constraints.maxWidth,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: isSmallScreen ? 20 : 40),
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 10 : 20),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Image.asset(
                            'assets/logoWithProjectName.png',
                            height: isSmallScreen ? screenWidth * 0.35 : screenWidth * 0.25,
                            width: isSmallScreen ? screenWidth * 0.35 : screenWidth * 0.25,
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 30),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmallScreen ? 15 : 30),
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode ? Colors.black.withOpacity(0.3) : AppColors.borderColor.withOpacity(0.5),
                                blurRadius: 6,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ravie de vous revoir !',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 18 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 5 : 10),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 20),
                                  child: Text(
                                    'Connectez-vous à votre compte existant',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 16,
                                      color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 15 : 30),
                                TextFormField(
                                  controller: _emailController,
                                  style: TextStyle(fontSize: isSmallScreen ? 14 : null, color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixIcon: Icon(Icons.email, size: isSmallScreen ? 20 : null, color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor),
                                    labelText: "Email",
                                    labelStyle: TextStyle(fontSize: isSmallScreen ? 14 : null, color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: isDarkMode ? AppColors.darkBackgroundColor : Colors.white,
                                    contentPadding: isSmallScreen ? const EdgeInsets.symmetric(vertical: 10, horizontal: 10) : null,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre email';
                                    }
                                    final emailRegex = RegExp(r"^[a-zA-Z0-9]+([._%+-][a-zA-Z0-9]+)*@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$");
                                    if (!emailRegex.hasMatch(value.trim())) {
                                      return 'Format d\'email invalide';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: isSmallScreen ? 10 : 20),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(fontSize: isSmallScreen ? 14 : null, color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixIcon: Icon(Icons.lock, size: isSmallScreen ? 20 : null, color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor),
                                    labelText: "Mot de passe",
                                    labelStyle: TextStyle(fontSize: isSmallScreen ? 14 : null, color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor, width: 2),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: isSmallScreen ? 20 : null, color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: isDarkMode ? AppColors.darkBackgroundColor : Colors.white,
                                    contentPadding: isSmallScreen ? const EdgeInsets.symmetric(vertical: 10, horizontal: 10) : null,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer un mot de passe';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: isSmallScreen ? 5 : 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/ResetPasswordPage');
                                    },
                                    child: Text(
                                      'Mot de passe oublié',
                                      style: TextStyle(fontSize: isSmallScreen ? 12 : null, color: isDarkMode ? AppColors.darkSecondaryColor : AppColors.secondaryColor),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
                                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                      height: isSmallScreen ? 20 : 24,
                                      width: isSmallScreen ? 20 : 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: AppColors.buttonTextColor,
                                      ),
                                    )
                                        : Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        color: AppColors.buttonTextColor,
                                        fontSize: isSmallScreen ? 14 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 15 : 25),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor, thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        'Ou',
                                        style: TextStyle(fontSize: isSmallScreen ? 12 : null, color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor, thickness: 1)),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 15 : 25),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _isGoogleLoading
                                        ? null
                                        : () async {
                                      setState(() => _isGoogleLoading = true);
                                      try {
                                        final (userCredential, isNewUser) = await Auth().signInWithGoogle();
                                        if (userCredential != null && mounted) {
                                          _showSuccessSnackbar(isNewUser
                                              ? 'Inscription réussie avec Google !'
                                              : 'Connexion réussie avec Google !');
                                          await _messagingService.sendLocalNotification(
                                            'Connexion réussie',
                                            'Bienvenue de retour avec Google !',
                                          );
                                          await Future.delayed(const Duration(seconds: 2));
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (_) => const RedirectionPage()),
                                          );
                                        }
                                      } on FirebaseAuthException catch (e) {
                                        if (e.code != 'cancelled' && mounted) {
                                          _handleFirebaseAuthError(e);
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          _showErrorSnackbar('Erreur inattendue', 'Erreur lors de la connexion Google');
                                        }
                                      } finally {
                                        if (mounted) setState(() => _isGoogleLoading = false);
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      side: BorderSide(
                                        color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor,
                                      ),
                                      backgroundColor: isDarkMode ? AppColors.darkBackgroundColor : Colors.white,
                                    ),
                                    child: _isGoogleLoading
                                        ? SizedBox(
                                      height: isSmallScreen ? 20 : 24,
                                      width: isSmallScreen ? 20 : 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
                                      ),
                                    )
                                        : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'assets/google_icon.png',
                                          height: isSmallScreen ? 22 : 28,
                                          width: isSmallScreen ? 22 : 28,
                                        ),
                                        SizedBox(width: isSmallScreen ? 8 : 12),
                                        Flexible(
                                          child: Text(
                                            'Se connecter avec Google',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 14 : 16,
                                              color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                                            ),
                                          ),
                                        ), 
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 15 : 25),
                                Padding(
                                  padding: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/SignUpPage');
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Pas encore de compte ? ',
                                            style: TextStyle(
                                              color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                                              fontSize: isSmallScreen ? 12 : 15,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'INSCRIVEZ-VOUS',
                                            style: TextStyle(
                                              color: isDarkMode ? AppColors.darkSecondaryColor : AppColors.secondaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: isSmallScreen ? 12 : 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await Auth().loginWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          // Remove _showSuccessSnackbar and keep only the notification
          await _messagingService.sendLocalNotification(
            'Connexion réussie',
            'Bienvenu de retour !',
          );
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RedirectionPage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        _handleFirebaseAuthError(e);
      } catch (e) {
        _showErrorSnackbar('Erreur', 'Une erreur s\'est produite');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage;
    final email = _emailController.text.trim();
    switch (e.code) {
      case 'invalid-email':
        errorMessage = "L'adresse email « $email » n'est pas valide. Exemple attendu : nom.prenom@email.com";
        break;
      case 'user-not-found':
        errorMessage = "Aucun compte n'est associé à l'email « $email ». Vérifiez l'orthographe ou créez un nouveau compte.";
        break;
      case 'wrong-password':
        errorMessage = "Le mot de passe saisi pour l'email « $email » est incorrect. Vérifiez les majuscules/minuscules ou réinitialisez-le si besoin.";
        break;
      case 'network-request-failed':
        errorMessage = "Connexion impossible : aucun accès Internet détecté. Vérifiez votre réseau Wi-Fi ou données mobiles.";
        break;
      default:
        errorMessage = "Une erreur inattendue est survenue. Veuillez réessayer dans quelques instants.";
    }
    _showErrorSnackbar('Erreur de connexion', errorMessage);
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    _messagingService.sendLocalNotification('Succès', message);
  }

  void _showErrorSnackbar(String title, String message) {
    if (!mounted) return;
    _messagingService.sendLocalNotification(title, message);
  }
}