import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp/otp.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'dart:convert';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate or get device ID
  Future<String> _getDeviceId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      // Generate a unique device ID
      final random = Random.secure();
      final bytes = List<int>.generate(16, (i) => random.nextInt(256));
      deviceId = base64Url.encode(bytes);
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }

  // Check if current device is trusted for the user
  Future<bool> _isDeviceTrusted(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      
      // Get trusted devices for this user
      final trustedDevicesJson = prefs.getString('trusted_devices_$userId');
      if (trustedDevicesJson == null) return false;
      
      final trustedDevices = Map<String, dynamic>.from(
        jsonDecode(trustedDevicesJson)
      );
      
      // Check if current device is in trusted list and not expired
      if (trustedDevices.containsKey(deviceId)) {
        final deviceInfo = trustedDevices[deviceId];
        final expiryTime = DateTime.parse(deviceInfo['expiry']);
        
        if (DateTime.now().isBefore(expiryTime)) {
          return true;
        } else {
          // Remove expired device
          trustedDevices.remove(deviceId);
          await prefs.setString('trusted_devices_$userId', jsonEncode(trustedDevices));
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking trusted device: $e');
      return false;
    }
  }

  // Add current device to trusted devices
  Future<void> _addTrustedDevice(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      
      // Get existing trusted devices or create new map
      final trustedDevicesJson = prefs.getString('trusted_devices_$userId');
      Map<String, dynamic> trustedDevices = {};
      
      if (trustedDevicesJson != null) {
        trustedDevices = Map<String, dynamic>.from(
          jsonDecode(trustedDevicesJson)
        );
      }
      
      // Add current device with 30-day expiry
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      trustedDevices[deviceId] = {
        'added': DateTime.now().toIso8601String(),
        'expiry': expiryDate.toIso8601String(),
        'name': 'This Device',
      };
      
      // Save updated trusted devices
      await prefs.setString('trusted_devices_$userId', jsonEncode(trustedDevices));
    } catch (e) {
      print('Error adding trusted device: $e');
    }
  }

  bool _verifyTOTP(String token, String secretKey) {
    if (token.length != 6) return false;
    
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Check multiple time windows to account for clock drift
      for (int i = -2; i <= 2; i++) {
        final timeStep = (now ~/ 30) + i;
        final generatedCode = OTP.generateTOTPCodeString(
          secretKey,
          timeStep * 30 * 1000, // Convert to milliseconds
          length: 6,
          interval: 30,
          algorithm: Algorithm.SHA1,
        );
        
        if (token == generatedCode) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('TOTP verification error: $e');
      return false;
    }
  }

  // Alternative verification method using manual HMAC calculation
  bool _verifyTOTPManual(String token, String secretKey) {
    if (token.length != 6) return false;
    
    try {
      // Decode base32 secret
      final secretBytes = _base32Decode(secretKey);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Check multiple time windows
      for (int i = -2; i <= 2; i++) {
        final timeStep = (now ~/ 30) + i;
        final timeBytes = _intToBytes(timeStep);
        
        // Generate HMAC-SHA1
        final hmac = Hmac(sha1, secretBytes);
        final hash = hmac.convert(timeBytes).bytes;
        
        // Dynamic truncation
        final offset = hash[hash.length - 1] & 0x0F;
        final code = ((hash[offset] & 0x7F) << 24) |
                    ((hash[offset + 1] & 0xFF) << 16) |
                    ((hash[offset + 2] & 0xFF) << 8) |
                    (hash[offset + 3] & 0xFF);
        
        final otp = (code % 1000000).toString().padLeft(6, '0');
        
        if (token == otp) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Manual TOTP verification error: $e');
      return false;
    }
  }

  List<int> _base32Decode(String input) {
    const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final result = <int>[];
    int buffer = 0;
    int bitsLeft = 0;
    
    for (int i = 0; i < input.length; i++) {
      final char = input[i].toUpperCase();
      final value = base32Chars.indexOf(char);
      if (value == -1) continue;
      
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      
      if (bitsLeft >= 8) {
        result.add((buffer >> (bitsLeft - 8)) & 0xFF);
        bitsLeft -= 8;
      }
    }
    
    return result;
  }

  List<int> _intToBytes(int value) {
    final result = <int>[];
    for (int i = 7; i >= 0; i--) {
      result.add((value >> (i * 8)) & 0xFF);
    }
    return result;
  }

  Future<void> _show2FADialog(User user) async {
    final codeController = TextEditingController();
    bool isVerifying = false;
    bool trustThisDevice = true; // Default to trust device
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final secretKey = prefs.getString('2fa_secret_${user.uid}');
    
    if (secretKey == null) {
      _navigateToHome();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Two-Factor Authentication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the 6-digit code from your authenticator app:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Authentication Code',
                  border: OutlineInputBorder(),
                  counterText: '',
                  helperText: 'Enter the code from Google Authenticator',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                autofocus: true,
              ),
              const SizedBox(height: 16),
              
              // Trust device checkbox
              Row(
                children: [
                  Checkbox(
                    value: trustThisDevice,
                    onChanged: (value) {
                      setDialogState(() {
                        trustThisDevice = value ?? false;
                      });
                    },
                    activeColor: Colors.brown.shade800,
                  ),
                  const Expanded(
                    child: Text(
                      'Trust this device for 30 days',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const Text(
                'You won\'t need to enter 2FA codes on this device for 30 days.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying ? null : () async {
                final code = codeController.text.trim();
                
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a 6-digit code'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isVerifying = true);

                // Add a small delay to prevent UI freezing
                await Future.delayed(const Duration(milliseconds: 100));

                try {
                  // Try both verification methods
                  bool isValid = _verifyTOTP(code, secretKey) || _verifyTOTPManual(code, secretKey);
                  
                  if (isValid) {
                    // Add device to trusted list if checkbox is checked
                    if (trustThisDevice) {
                      await _addTrustedDevice(user.uid);
                    }
                    
                    Navigator.pop(context, true);
                  } else {
                    setDialogState(() => isVerifying = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid code. Please try again.\nMake sure your device time is correct.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    codeController.clear();
                  }
                } catch (e) {
                  setDialogState(() => isVerifying = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade800,
              ),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _navigateToHome();
    } else {
      await _auth.signOut();
      setState(() {
        _isLoading = false;
        _errorText = "Authentication cancelled";
      });
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final is2FAEnabled = prefs.getBool('2fa_enabled_${userCredential.user!.uid}') ?? false;
        
        if (is2FAEnabled) {
          // Check if device is already trusted
          final isDeviceTrusted = await _isDeviceTrusted(userCredential.user!.uid);
          
          if (isDeviceTrusted) {
            // Device is trusted, skip 2FA
            print('Device is trusted, skipping 2FA');
            _navigateToHome();
          } else {
            // Device not trusted, show 2FA dialog
            await _show2FADialog(userCredential.user!);
          }
        } else {
          _navigateToHome();
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorText = "No user found for that email.";
            break;
          case 'wrong-password':
            _errorText = "Incorrect password.";
            break;
          case 'invalid-email':
            _errorText = "Invalid email address.";
            break;
          case 'too-many-requests':
            _errorText = "Too many failed attempts. Please try again later.";
            break;
          case 'user-disabled':
            _errorText = "This account has been disabled.";
            break;
          default:
            _errorText = "Login failed. Please try again.";
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = "An unexpected error occurred.";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Log into",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                "your account",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              _buildTextField("Email address", _emailController),
              const SizedBox(height: 20),

              _buildTextField("Password", _passwordController, obscure: true),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Implement Forgot Password
                  },
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "LOG IN",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 30),
              const Center(child: Text("or log in with")),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon('assets/icon/apple.png'),
                  const SizedBox(width: 16),
                  _socialIcon('assets/icon/email.png'),
                  const SizedBox(width: 16),
                  _socialIcon('assets/icon/facebook.jpeg'),
                ],
              ),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text("Sign Up"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: label.toLowerCase().contains('email')
            ? TextInputType.emailAddress
            : TextInputType.text,
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(String path) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      backgroundImage: AssetImage(path),
    );
  }
}