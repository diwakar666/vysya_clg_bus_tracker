import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: const FirebaseOptions(
        apiKey: "AIzaSyBHfrYNλoSLEHZ-gndK3vb8xerejoW0IPI",
        appId: "1:149177498381:web:1a66343885c280dbb64e44",
        messagingSenderId: "149177498381",
        projectId: "vysya-clg-bus-tracker-565b8",
        databaseURL: "https://vysya-clg-bus-tracker-565b8-default-rtdb.firebaseio.com",
       ),    
     ); 
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StudentLoginPage(),
  ));
}

// 1. LOGIN & BUS SELECTION SCREEN
class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedBus = 'Bus 1';

  final List<String> _busList = ['Bus 1', 'Bus 2', 'Bus 3', 'Bus 4'];

  void _login() {
    if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentTrackingScreen(
            studentName: _usernameController.text,
            busId: _selectedBus,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Username & Password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Login'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username / Roll No',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedBus,
              decoration: const InputDecoration(
                labelText: 'Select Your Bus',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_bus),
              ),
              items: _busList.map((String bus) {
                return DropdownMenuItem<String>(
                  value: bus,
                  child: Text(bus),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedBus = val!),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _login,
              child: const Text('TRACK BUS', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. LIVE TRACKING & 2KM ALARM SCREEN
class StudentTrackingScreen extends StatefulWidget {
  final String studentName;
  final String busId;

  const StudentTrackingScreen({
    super.key,
    required this.studentName,
    required this.busId,
  });

  @override
  State<StudentTrackingScreen> createState() => _StudentTrackingScreenState();
}

class _StudentTrackingScreenState extends State<StudentTrackingScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Position? _studentPos;
  double? _busLat;
  double? _busLng;
  double _distanceInKm = 0.0;
  bool _alarmTriggered = false;

  StreamSubscription? _busStream;
  StreamSubscription? _posStream;

  @override
  void initState() {
    super.initState();
    _initStudentLocation();
    _listenToBusLocation();
  }

  void _initStudentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position pos) {
      setState(() {
        _studentPos = pos;
        _calculateDistance();
      });
    });
  }

  void _listenToBusLocation() {
    _busStream = _dbRef.child('buses/${widget.busId}').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['lat'] != null && data['lng'] != null) {
        setState(() {
          _busLat = (data['lat'] as num).toDouble();
          _busLng = (data['lng'] as num).toDouble();
          _calculateDistance();
        });
      }
    });
  }

  void _calculateDistance() {
    if (_studentPos != null && _busLat != null && _busLng != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        _studentPos!.latitude,
        _studentPos!.longitude,
        _busLat!,
        _busLng!,
      );

      setState(() {
        _distanceInKm = distanceInMeters / 1000;
      });

      // 2 KM ALARM LOGIC
      if (_distanceInKm <= 2.0 && !_alarmTriggered) {
        _triggerAlarm();
      }
    }
  }

  void _triggerAlarm() async {
    _alarmTriggered = true;
    // Online Notification Beep Sound
    await _audioPlayer.play(
      UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🚨 Bus Arriving Soon!'),
          content: Text('${widget.busId} is within 2 km (${_distanceInKm.toStringAsFixed(2)} km away). Get ready!'),
          actions: [
            TextButton(
              onPressed: () {
                _audioPlayer.stop();
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _busStream?.cancel();
    _posStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.busId} Live Status'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Welcome, ${widget.studentName}!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: [
                      Icon(
                        _distanceInKm <= 2.0 && _distanceInKm > 0 ? Icons.alarm_on : Icons.directions_bus,
                        size: 60,
                        color: _distanceInKm <= 2.0 && _distanceInKm > 0 ? Colors.red : Colors.indigo,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        _busLat == null ? 'Waiting for Driver...' : '${_distanceInKm.toStringAsFixed(2)} KM Away',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _distanceInKm <= 2.0 && _distanceInKm > 0
                            ? '🚨 Bus is very close! Prepare to board.'
                            : 'Bus is on the way.',
                        style: TextStyle(
                          color: _distanceInKm <= 2.0 && _distanceInKm > 0 ? Colors.red : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}