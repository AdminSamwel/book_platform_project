import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'reader';
  final _formKey = GlobalKey<FormState>();

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        await context.read<AuthProvider>().register(_usernameCtrl.text, _passCtrl.text, _role);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Jisajili")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Jina'),
                validator: (v) => v!.isEmpty ? 'Lazima' : null,
              ),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nywila'),
                validator: (v) => v!.isEmpty ? 'Lazima' : null,
              ),
              DropdownButtonFormField(
                initialValue: _role,
                items: const [
                  DropdownMenuItem(value: 'reader', child: Text("Msomaji")),
                  DropdownMenuItem(value: 'author', child: Text("Mwandishi")),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _register, child: const Text("Jisajili")),
            ],
          ),
        ),
      ),
    );
  }
}