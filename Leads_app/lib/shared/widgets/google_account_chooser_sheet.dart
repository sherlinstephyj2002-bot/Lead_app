import 'package:flutter/material.dart';
import '../../constants/user_roles.dart';

class GoogleAccountChooserSheet extends StatefulWidget {
  const GoogleAccountChooserSheet({super.key});

  @override
  State<GoogleAccountChooserSheet> createState() => _GoogleAccountChooserSheetState();
}

class _GoogleAccountChooserSheetState extends State<GoogleAccountChooserSheet> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showCustomInput = false;

  final List<Map<String, dynamic>> _mockAccounts = [
    {
      'email': 'admin.demo@gmail.com',
      'name': 'Admin Demo',
      'role': UserRoles.companyAdmin,
      'initial': 'A',
      'avatarColor': const Color(0xFF8D6E63), // Brown
      'signedOut': false,
    },
    {
      'email': 'manager.demo@gmail.com',
      'name': 'Manager Demo',
      'role': UserRoles.companyAdmin,
      'initial': 'M',
      'avatarColor': const Color(0xFFEC407A), // Pink
      'signedOut': true,
    },
    {
      'email': 'employee.demo@gmail.com',
      'name': 'Employee Demo',
      'role': UserRoles.employee,
      'initial': 'E',
      'avatarColor': const Color(0xFFEF5350), // Red
      'signedOut': true,
    },
    {
      'email': 'testuser@gmail.com',
      'name': 'Test User',
      'role': UserRoles.companyAdmin,
      'initial': 'T',
      'avatarColor': const Color(0xFFAB47BC), // Purple
      'signedOut': true,
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _selectEmail(String email) {
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131314), // Deep Google Dark Theme black
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center indicator handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF444746), // Darker gray handle
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header with Google Branding in Dark Mode
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://developers.google.com/identity/images/g-logo.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_circle_outlined,
                    color: Color(0xFFA8C7FA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Choose an account title & subtitle
            const Text(
              'Choose an account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            const Text(
              'to continue to WorkTrack',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFC4C7C5), // Google gray secondary text
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 24),

            if (!_showCustomInput) ...[
              // Divider before list
              const Divider(height: 1, color: Color(0xFF333537)),
              
              // List of Mock Accounts styled like Google Account Chooser
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _mockAccounts.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  color: Color(0xFF333537),
                ),
                itemBuilder: (context, index) {
                  final account = _mockAccounts[index];
                  final email = account['email']!;
                  final name = account['name']!;
                  final role = account['role']!;
                  final initial = account['initial']!;
                  final Color avatarColor = account['avatarColor']!;
                  final bool isSignedOut = account['signedOut']!;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                    hoverColor: const Color(0xFF202124),
                    leading: CircleAvatar(
                      backgroundColor: avatarColor,
                      radius: 18,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFC4C7C5)),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2022),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF444746), width: 0.5),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA8C7FA),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: isSignedOut
                        ? const Text(
                            'Signed out',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC4C7C5),
                            ),
                          )
                        : null,
                    onTap: () => _selectEmail(email),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFF333537)),
              
              // Option to use another account
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                leading: const CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 18,
                  child: Icon(Icons.person_add_alt_1_outlined, color: Color(0xFFC4C7C5), size: 20),
                ),
                title: const Text(
                  'Use another account',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Color(0xFFE3E3E3),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E918F), size: 20),
                onTap: () {
                  setState(() {
                    _showCustomInput = true;
                  });
                },
              ),
              const Divider(height: 1, color: Color(0xFF333537)),
              const SizedBox(height: 20),
              
              // Scroll / Expand circular button at the bottom (matching screenshot)
              Center(
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF004A77), // Google Accent Dark Blue
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ] else ...[
              // Custom Email Form in Google Dark Mode Theme
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter custom Google email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        labelStyle: const TextStyle(color: Color(0xFFC4C7C5)),
                        hintText: 'e.g. user@gmail.com',
                        hintStyle: const TextStyle(color: Color(0xFF8E918F)),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFC4C7C5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF444746)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFA8C7FA), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an email address';
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _showCustomInput = false;
                                _emailController.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              side: const BorderSide(color: Color(0xFF444746)),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(color: Color(0xFFA8C7FA), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _selectEmail(_emailController.text.trim());
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA8C7FA), // Google Blue Accent
                              foregroundColor: const Color(0xFF131314),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
