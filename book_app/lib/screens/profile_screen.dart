import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  final _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.fetchProfile();
      setState(() {
        _profile = data;
        _bioCtrl.text = data['bio'] ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final res = await _api.updateProfile(bio: _bioCtrl.text.trim());
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wasifu umehifadhiwa!')));
        }
      } else {
        throw Exception('Imeshindwa kuhifadhi');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasifu Wangu'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Imeshindwa kupakia wasifu.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.indigo.shade100,
                        backgroundImage: _profile!['avatar'] != null
                            ? NetworkImage(_profile!['avatar']) as ImageProvider
                            : null,
                        child: _profile!['avatar'] == null
                            ? const Icon(Icons.person, size: 50, color: Colors.indigo)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile!['username'] ?? '',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _profile!['role'] == 'author' ? 'Mwandishi' : 'Msomaji',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Maelezo ya Kibinafsi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bioCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Jieleze kidogo...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Hifadhi Mabadiliko'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
