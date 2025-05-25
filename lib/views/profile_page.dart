import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:otp/otp.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_project/views/auth_selector_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _is2FAEnabled = false;
  String? _secretKey;

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
  }

  Future<void> _load2FAStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _is2FAEnabled = prefs.getBool('2fa_enabled_${user?.uid}') ?? false;
        _secretKey = prefs.getString('2fa_secret_${user?.uid}');
      });
    } catch (e) {
      print('Error loading 2FA status: $e');
    }
  }

  String _generateSecretKey() {
    // Generate a proper base32 secret key
    const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = Random.secure();
    
    // Generate 20 random bytes and convert to base32
    final bytes = List<int>.generate(20, (i) => random.nextInt(256));
    String result = '';
    
    int buffer = 0;
    int bitsLeft = 0;
    
    for (int byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;
      
      while (bitsLeft >= 5) {
        result += base32Chars[(buffer >> (bitsLeft - 5)) & 31];
        bitsLeft -= 5;
      }
    }
    
    if (bitsLeft > 0) {
      result += base32Chars[(buffer << (5 - bitsLeft)) & 31];
    }
    
    return result;
  }

  String _generateQRCodeData(String secretKey) {
    final email = user?.email ?? 'user@example.com';
    final issuer = 'GemStore';
    return 'otpauth://totp/$issuer:$email?secret=$secretKey&issuer=$issuer&algorithm=SHA1&digits=6&period=30';
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

  // ADD THIS NEW METHOD FOR TRUSTED DEVICES MANAGEMENT
  void _manageTrustedDevices() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final trustedDevicesJson = prefs.getString('trusted_devices_${user?.uid}');
    
    Map<String, dynamic> trustedDevices = {};
    if (trustedDevicesJson != null) {
      trustedDevices = Map<String, dynamic>.from(jsonDecode(trustedDevicesJson));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trusted Devices'),
        content: SizedBox(
          width: double.maxFinite,
          child: trustedDevices.isEmpty
              ? const Text('No trusted devices found.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: trustedDevices.length,
                  itemBuilder: (context, index) {
                    final deviceId = trustedDevices.keys.elementAt(index);
                    final deviceInfo = trustedDevices[deviceId];
                    final expiryDate = DateTime.parse(deviceInfo['expiry']);
                    final isExpired = DateTime.now().isAfter(expiryDate);
                    
                    return ListTile(
                      leading: Icon(
                        Icons.devices,
                        color: isExpired ? Colors.grey : Colors.green,
                      ),
                      title: Text(deviceInfo['name'] ?? 'Unknown Device'),
                      subtitle: Text(
                        isExpired 
                            ? 'Expired on ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}'
                            : 'Expires on ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.grey,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          trustedDevices.remove(deviceId);
                          await prefs.setString(
                            'trusted_devices_${user?.uid}',
                            jsonEncode(trustedDevices),
                          );
                          Navigator.pop(context);
                          _manageTrustedDevices(); // Refresh the dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Device removed from trusted list'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (trustedDevices.isNotEmpty)
            TextButton(
              onPressed: () async {
                // Remove all trusted devices
                await prefs.remove('trusted_devices_${user?.uid}');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All trusted devices removed'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text(
                'Remove All',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  void _setup2FA() {
    final secretKey = _generateSecretKey();
    final qrData = _generateQRCodeData(secretKey);
    final codeController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Setup Two-Factor Authentication'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '1. Install Google Authenticator\n'
                    '2. Scan this QR code\n'
                    '3. Enter the 6-digit code',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 16),
                  
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 180.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Secret Key
                  const Text(
                    'Manual Entry Key:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            secretKey,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: secretKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Secret key copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Code Input
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter 6-digit code',
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
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(context),
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
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('2fa_enabled_${user?.uid}', true);
                    await prefs.setString('2fa_secret_${user?.uid}', secretKey);

                    setState(() {
                      _is2FAEnabled = true;
                      _secretKey = secretKey;
                    });

                    Navigator.pop(context);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Two-Factor Authentication enabled successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    setDialogState(() => isVerifying = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid code. Please try again.'),
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
                  : const Text('Verify & Enable'),
            ),
          ],
        ),
      ),
    );
  }

  void _disable2FA() {
    if (_secretKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No 2FA secret found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final codeController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Disable Two-Factor Authentication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your current 6-digit authentication code to disable 2FA:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Authentication Code',
                  border: OutlineInputBorder(),
                  counterText: '',
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
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(context),
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
                  bool isValid = _verifyTOTP(code, _secretKey!) || _verifyTOTPManual(code, _secretKey!);
                  
                  if (isValid) {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('2fa_enabled_${user?.uid}');
                    await prefs.remove('2fa_secret_${user?.uid}');
                    // Also remove all trusted devices when disabling 2FA
                    await prefs.remove('trusted_devices_${user?.uid}');

                    setState(() {
                      _is2FAEnabled = false;
                      _secretKey = null;
                    });

                    Navigator.pop(context);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Two-Factor Authentication disabled'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } else {
                    setDialogState(() => isVerifying = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid code. Please try again.'),
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
                backgroundColor: Colors.red,
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
                  : const Text('Disable'),
            ),
          ],
        ),
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Change Password"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Current Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter your current password";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return "Enter at least 6 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return "Passwords do not match";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => isLoading = true);

                  try {
                    final credential = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: currentPasswordController.text,
                    );
                    await user!.reauthenticateWithCredential(credential);
                    await user!.updatePassword(newPasswordController.text);

                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Password updated successfully"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    String errorMessage = "Error updating password";

                    if (e is FirebaseAuthException) {
                      switch (e.code) {
                        case 'wrong-password':
                          errorMessage = "Current password is incorrect";
                          break;
                        case 'weak-password':
                          errorMessage = "New password is too weak";
                          break;
                        default:
                          errorMessage = e.message ?? errorMessage;
                      }
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade800,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _editDisplayName(BuildContext context) {
    final nameController = TextEditingController(text: user?.displayName ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Name"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Display Name",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Name cannot be empty"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isLoading = true);

                try {
                  await user!.updateDisplayName(nameController.text.trim());
                  await user!.reload();
                  setState(() {});
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Name updated successfully"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${e.toString()}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade800,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseAuth.instance.signOut();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_seen', true);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthSelectorScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error logging out: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFEA),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.brown.shade200,
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    user?.displayName ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 20,
                    color: Colors.brown.shade600,
                  ),
                  onPressed: () => _editDisplayName(context),
                ),
              ],
            ),

            Text(
              user?.email ?? 'No Email',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            Expanded(
              child: ListView(
                children: [
                  // Security Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Security",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade700,
                      ),
                    ),
                  ),

                  // Two-Factor Authentication
                  _buildProfileOption(
                    icon: _is2FAEnabled ? Icons.security : Icons.security_outlined,
                    title: "Two-Factor Authentication",
                    subtitle: _is2FAEnabled ? "Enabled" : "Disabled",
                    iconColor: _is2FAEnabled ? Colors.green : Colors.orange,
                    backgroundColor: _is2FAEnabled ? Colors.green.shade50 : Colors.orange.shade50,
                    trailing: Switch(
                      value: _is2FAEnabled,
                      onChanged: (value) {
                        if (value) {
                          _setup2FA();
                        } else {
                          _disable2FA();
                        }
                      },
                      activeColor: Colors.green,
                    ),
                    onTap: () {
                      if (_is2FAEnabled) {
                        _disable2FA();
                      } else {
                        _setup2FA();
                      }
                    },
                  ),

                  // ADD THE TRUSTED DEVICES OPTION HERE (only show if 2FA is enabled)
                  if (_is2FAEnabled) ...[
                    const SizedBox(height: 8),
                    _buildProfileOption(
                      icon: Icons.devices,
                      title: "Trusted Devices",
                      subtitle: "Manage devices that skip 2FA",
                      iconColor: Colors.blue,
                      backgroundColor: Colors.blue.shade50,
                      onTap: _manageTrustedDevices,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Change Password
                  _buildProfileOption(
                    icon: Icons.lock_outline,
                    title: "Change Password",
                    iconColor: Colors.brown,
                    backgroundColor: Colors.brown.shade50,
                    onTap: () => _changePassword(context),
                  ),

                  const SizedBox(height: 24),

                  // Account Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade700,
                      ),
                    ),
                  ),

                  // Logout
                  _buildProfileOption(
                    icon: Icons.logout,
                    title: "Log Out",
                    iconColor: Colors.redAccent,
                    backgroundColor: Colors.red.shade50,
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required Color backgroundColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: backgroundColor,
      ),
    );
  }
}